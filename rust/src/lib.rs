use std::collections::BTreeMap;
use std::fs;
use std::str::FromStr;
use std::sync::Arc;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use bitcoin_hashes::Hash;
use bitcoin_hashes::sha256;
use chrono::{DateTime, Local};
use lightning_invoice::Bolt11Invoice;
use lnurl_pay::LnUrl;
use rusqlite::Connection;
use serde::{Deserialize, Serialize};
use tokio::sync::Mutex;
use tokio::time::sleep;

#[derive(Clone, Serialize, Deserialize)]
#[flutter_rust_bridge::frb]
pub struct Payment {
    pub id: String,
    pub amount_fiat: i64,
    pub amount_msat: i64,
    pub created_at: i64, // Unix timestamp
}

#[flutter_rust_bridge::frb(opaque)]
pub struct LnUrlWrapper(LnUrl);

#[flutter_rust_bridge::frb(sync)]
pub fn parse_lnurl(lnurl: &str) -> Result<LnUrlWrapper, String> {
    if let Some(stripped) = lnurl.strip_prefix("lightning:") {
        return parse_lnurl(stripped);
    }

    if let Some(stripped) = lnurl.strip_prefix("lnurl:") {
        return parse_lnurl(stripped);
    }

    LnUrl::from_str(lnurl)
        .map(LnUrlWrapper)
        .map_err(|_| "Invalid LNURL".to_string())
}

#[flutter_rust_bridge::frb(opaque)]
pub struct LnurlClient {
    lnurl: LnUrl,
    currency_code: String,
    currency_symbol: String,
    currency_name: String,
    db_conn: Arc<std::sync::Mutex<Connection>>,
    exchange_rate: Arc<Mutex<Option<(FediPriceResponse, Instant)>>>,
    lnurl_response: Arc<Mutex<Option<(LnUrlPayResponse, Instant)>>>,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct LnurlClientConfig {
    lnurl: LnUrl,
    currency_code: String,
    currency_symbol: String,
    currency_name: String,
}

fn init_database(data_dir: &str) -> Connection {
    let conn = Connection::open(format!("{data_dir}/data.sqlite")).unwrap();

    conn.execute(
        "CREATE TABLE IF NOT EXISTS payment (
            id TEXT PRIMARY KEY,
            amount_fiat INTEGER NOT NULL,
            amount_msat INTEGER NOT NULL,
            created_at INTEGER NOT NULL
        )",
        [],
    )
    .unwrap();

    conn
}

impl LnurlClient {
    /// Create a new lnurl client instance
    #[flutter_rust_bridge::frb(sync)]
    pub fn persist(
        data_dir: &str,
        lnurl: &LnUrlWrapper,
        currency_code: &str,
        currency_symbol: &str,
        currency_name: &str,
    ) {
        let config = LnurlClientConfig {
            lnurl: lnurl.0.clone(),
            currency_code: currency_code.to_string(),
            currency_symbol: currency_symbol.to_string(),
            currency_name: currency_name.to_string(),
        };

        let config = serde_json::to_string(&config).unwrap();

        fs::write(format!("{data_dir}/config.json"), config).unwrap();
    }

    /// Load the lnurl client from the config file
    #[flutter_rust_bridge::frb(sync)]
    pub fn load(data_dir: &str) -> Option<Self> {
        let config = fs::read_to_string(format!("{data_dir}/config.json")).ok()?;

        let config: LnurlClientConfig = serde_json::from_str(&config).ok()?;

        Some(Self {
            lnurl: config.lnurl,
            currency_code: config.currency_code,
            currency_symbol: config.currency_symbol,
            currency_name: config.currency_name,
            db_conn: Arc::new(std::sync::Mutex::new(init_database(data_dir))),
            exchange_rate: Arc::new(Mutex::new(None)),
            lnurl_response: Arc::new(Mutex::new(None)),
        })
    }

    /// Update the exchange rate and LNURL response caches
    #[flutter_rust_bridge::frb]
    pub async fn update_caches(&self) {
        tokio::task::spawn(fetch_exchange_rate(self.exchange_rate.clone()));

        tokio::task::spawn(fetch_lnurl_response(
            self.lnurl_response.clone(),
            self.lnurl.endpoint(),
        ));
    }

    /// Get an invoice for a given amount in minor units (e.g., cents)
    #[flutter_rust_bridge::frb]
    pub async fn resolve(&self, amount_fiat: i64) -> Result<Invoice, String> {
        tokio::time::timeout(
            Duration::from_secs(30),
            self.resolve_without_timeout(amount_fiat),
        )
        .await
        .map_err(|_| "Request timeout".to_string())?
    }

    pub async fn resolve_without_timeout(&self, amount_fiat: i64) -> Result<Invoice, String> {
        let (invoice, verify) = resolve_amount_with_currency_code(
            fetch_exchange_rate(self.exchange_rate.clone()).await?,
            fetch_lnurl_response(self.lnurl_response.clone(), self.lnurl.endpoint()).await?,
            self.currency_code.clone(),
            amount_fiat,
        )
        .await?;

        Ok(Invoice {
            invoice,
            verify,
            amount_fiat,
            db_conn: self.db_conn.clone(),
        })
    }

    /// List all known successful payments
    #[flutter_rust_bridge::frb(sync)]
    pub fn list_payments(&self) -> Vec<Payment> {
        self.db_conn
            .lock()
            .unwrap()
            .prepare("SELECT * FROM payment ORDER BY created_at DESC")
            .unwrap()
            .query_map([], |row| {
                Ok(Payment {
                    id: row.get(0)?,
                    amount_fiat: row.get(1)?,
                    amount_msat: row.get(2)?,
                    created_at: row.get(3)?,
                })
            })
            .unwrap()
            .map(|p| p.unwrap())
            .collect()
    }

    /// Delete all known successful payments
    #[flutter_rust_bridge::frb(sync)]
    pub fn delete_payments(&self) {
        self.db_conn
            .lock()
            .unwrap()
            .execute("DELETE FROM payment", [])
            .unwrap();
    }

    /// Sum the amounts in fiat over known history of payments
    #[flutter_rust_bridge::frb(sync)]
    pub fn sum_amounts_fiat(&self) -> i64 {
        self.list_payments().iter().map(|p| p.amount_fiat).sum()
    }

    /// Sum the amounts in millisatoshis over known history of payments
    #[flutter_rust_bridge::frb(sync)]
    pub fn sum_amounts_msat(&self) -> i64 {
        self.list_payments().iter().map(|p| p.amount_msat).sum()
    }

    /// Get the currency code
    #[flutter_rust_bridge::frb(sync)]
    pub fn currency_code(&self) -> String {
        self.currency_code.clone()
    }

    /// Get the currency symbol
    #[flutter_rust_bridge::frb(sync)]
    pub fn currency_symbol(&self) -> String {
        self.currency_symbol.clone()
    }

    /// Get the currency name
    #[flutter_rust_bridge::frb(sync)]
    pub fn currency_name(&self) -> String {
        self.currency_name.clone()
    }

    /// Export transactions as CSV with aligned formatting
    #[flutter_rust_bridge::frb(sync)]
    pub fn export_transactions_csv(&self) -> String {
        let mut csv = String::new();

        // Payment details with header
        csv.push_str(&format!(
            "Nr,{},Satoshis,Sum-{},Sum-Satoshis,Date\n",
            self.currency_code(),
            self.currency_code()
        ));

        let mut sum_amount_fiat: i64 = 0;
        let mut sum_amount_msat: i64 = 0;

        for (index, payment) in self.list_payments().iter().enumerate() {
            let date = DateTime::from_timestamp(payment.created_at / 1000, 0)
                .unwrap_or_default()
                .with_timezone(&Local)
                .format("%B-%d-%H:%M");

            sum_amount_fiat += payment.amount_fiat;
            sum_amount_msat += payment.amount_msat;

            csv.push_str(&format!(
                "{},{:.2},{},{:.2},{},{}\n",
                index + 1,
                payment.amount_fiat as f64 / 100.0,
                payment.amount_msat / 1000,
                sum_amount_fiat as f64 / 100.0,
                sum_amount_msat / 1000,
                date
            ));
        }

        csv
    }
}

#[flutter_rust_bridge::frb(opaque)]
pub struct Invoice {
    invoice: Bolt11Invoice,
    verify: String,
    amount_fiat: i64,
    db_conn: Arc<std::sync::Mutex<Connection>>,
}

impl Invoice {
    #[flutter_rust_bridge::frb(sync)]
    pub fn raw(&self) -> String {
        self.invoice.to_string()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn amount_msat(&self) -> i64 {
        self.invoice.amount_milli_satoshis().unwrap() as i64
    }

    #[flutter_rust_bridge::frb]
    pub async fn verify_payment(&self) -> Result<(), String> {
        tokio::task::spawn(Self::verification_task(
            self.verify.clone(),
            self.invoice.payment_hash().clone(),
            self.amount_fiat,
            self.amount_msat(),
            self.db_conn.clone(),
            self.invoice.expiry_time(),
        ))
        .await
        .unwrap()
    }

    async fn verification_task(
        verify: String,
        payment_hash: sha256::Hash,
        amount_fiat: i64,
        amount_msat: i64,
        db_conn: Arc<std::sync::Mutex<Connection>>,
        expiry_time: Duration,
    ) -> Result<(), String> {
        let start_time = Instant::now();

        while start_time.elapsed() < expiry_time {
            if let Ok(response) = Self::fetch_response(verify.clone()).await {
                match response {
                    VerifyResponse::Ok(success) => {
                        if success.settled {
                            let preimage = success
                                .preimage
                                .ok_or("Response is missing preimage".to_string())?;

                            let preimage = hex_conservative::decode_to_array::<32>(&preimage)
                                .map_err(|_| "Response preimage hex is invalid".to_string())?;

                            if sha256::Hash::hash(&preimage) != payment_hash {
                                return Err("Response preimage hash is invalid".to_string());
                            }

                            let created_at = SystemTime::now()
                                .duration_since(UNIX_EPOCH)
                                .unwrap()
                                .as_millis() as i64;

                            db_conn.lock().unwrap().execute(
                                "INSERT OR IGNORE INTO payment (id, amount_fiat, amount_msat, created_at) VALUES (?1, ?2, ?3, ?4)",
                                rusqlite::params![
                                    payment_hash.to_string(),
                                    amount_fiat,
                                    amount_msat,
                                    created_at,
                                ],
                            ).unwrap();

                            return Ok(());
                        }

                        sleep(Duration::from_secs(1)).await;
                    }
                    VerifyResponse::Error(..) => sleep(Duration::from_secs(10)).await,
                }
            };
        }

        Err("Invoice expired".to_string())
    }

    async fn fetch_response(verify: String) -> Result<VerifyResponse, String> {
        reqwest::get(&verify)
            .await
            .map_err(|_| "Failed to fetch verify callback response".to_string())?
            .json::<VerifyResponse>()
            .await
            .map_err(|_| "Failed to parse verify callback response".to_string())
    }
}

#[derive(Deserialize, Clone)]
struct FediPriceResponse {
    prices: BTreeMap<String, ExchangeRate>,
}

#[derive(Deserialize, Clone)]
struct ExchangeRate {
    rate: f64,
}

#[derive(Deserialize, Clone)]
struct LnUrlPayResponse {
    callback: String,
    #[serde(alias = "minSendable")]
    min_sendable: u64,
    #[serde(alias = "maxSendable")]
    max_sendable: u64,
}

#[derive(Deserialize, Clone)]
struct LnUrlPayInvoiceResponse {
    pr: Bolt11Invoice,
    verify: String,
}

#[derive(Deserialize, Clone)]
#[serde(tag = "status")]
pub enum VerifyResponse {
    #[serde(rename = "OK")]
    Ok(VerifySuccess),
    #[serde(rename = "ERROR")]
    Error(VerifyError),
}

#[derive(Deserialize, Clone)]
pub struct VerifySuccess {
    pub settled: bool,
    pub preimage: Option<String>,
    pub pr: String,
}

#[derive(Deserialize, Clone)]
pub struct VerifyError {
    pub reason: String,
}

async fn fetch_exchange_rate(
    cache: Arc<Mutex<Option<(FediPriceResponse, Instant)>>>,
) -> Result<FediPriceResponse, String> {
    let mut guard = cache.lock().await;

    #[allow(clippy::collapsible_if)]
    if let Some((value, timestamp)) = guard.as_ref() {
        if timestamp.elapsed() < Duration::from_secs(600) {
            return Ok(value.clone());
        }
    }

    let value = reqwest::get("https://price-feed.dev.fedibtc.com/latest")
        .await
        .map_err(|_| "Failed to fetch exchange rates".to_string())?
        .json::<FediPriceResponse>()
        .await
        .map_err(|_| "Failed to parse exchange rates".to_string())?;

    *guard = Some((value.clone(), Instant::now()));

    Ok(value)
}

async fn fetch_lnurl_response(
    cache: Arc<Mutex<Option<(LnUrlPayResponse, Instant)>>>,
    endpoint: String,
) -> Result<LnUrlPayResponse, String> {
    let mut guard = cache.lock().await;

    #[allow(clippy::collapsible_if)]
    if let Some((value, timestamp)) = guard.as_ref() {
        if timestamp.elapsed() < Duration::from_secs(600) {
            return Ok(value.clone());
        }
    }

    let value = reqwest::get(&endpoint)
        .await
        .map_err(|_| "Failed to fetch LNURL response".to_string())?
        .json::<LnUrlPayResponse>()
        .await
        .map_err(|_| "Failed to parse LNURL response".to_string())?;

    *guard = Some((value.clone(), Instant::now()));

    Ok(value)
}

async fn resolve_amount_with_currency_code(
    exchange_response: FediPriceResponse,
    lnurl_response: LnUrlPayResponse,
    currency_code: String,
    amount_fiat: i64,
) -> Result<(Bolt11Invoice, String), String> {
    // Step 1: Convert minor units to major units (e.g., 1234 cents → 12.34 EUR)
    let amount_fiat = amount_fiat as f64 / 100.0;

    // Step 2: Convert currency to USD (via exchange rate)
    let amount_in_usd = if currency_code == "USD" {
        amount_fiat
    } else {
        let currency_to_usd_rate = exchange_response
            .prices
            .get(&format!("{currency_code}/USD"))
            .ok_or("Selected currency not supported".to_string())?
            .rate;

        amount_fiat * currency_to_usd_rate
    };

    // Step 3: Convert USD to BTC
    let usd_to_btc_rate = exchange_response
        .prices
        .get("BTC/USD")
        .ok_or("BTC/USD rate not found".to_string())?
        .rate;

    let amount_in_btc = amount_in_usd / usd_to_btc_rate;

    // Step 4: Convert BTC to millisatoshis (1 BTC = 100,000,000,000 msat) but
    // rounded to full satoshis to be compatible with blink's api
    let amount_msat = (amount_in_btc * 100_000_000.0).round() as u64 * 1000;

    if amount_msat < lnurl_response.min_sendable {
        return Err("Amount too low".to_string());
    }

    if amount_msat > lnurl_response.max_sendable {
        return Err("Amount too high".to_string());
    }

    let callback_url = format!("{}?amount={}", lnurl_response.callback, amount_msat);

    let response = reqwest::get(callback_url)
        .await
        .map_err(|_| "Failed to fetch LNURL callback response".to_string())?
        .json::<LnUrlPayInvoiceResponse>()
        .await
        .map_err(|_| "Failed to parse LNURL callback response".to_string())?;

    if response.pr.amount_milli_satoshis().is_none() {
        return Err("Invoice amount is not set".to_string());
    }

    Ok((response.pr, response.verify))
}
