use std::{collections::BTreeMap, str::FromStr, time::Duration};

use lightning_invoice::Bolt11Invoice;
use lnurl_pay::LnUrl;
use serde::Deserialize;

#[flutter_rust_bridge::frb(opaque)]
pub struct LnurlClient {
    lnurl: LnUrl,
}

impl LnurlClient {
    /// Create a new lnurl client instance
    #[flutter_rust_bridge::frb]
    pub fn new_instance(lnurl: &str) -> Result<Self, String> {
        if let Some(stripped) = lnurl.strip_prefix("lightning:") {
            return Self::new_instance(stripped);
        }

        if let Some(stripped) = lnurl.strip_prefix("lnurl:") {
            return Self::new_instance(stripped);
        }

        let lnurl = LnUrl::from_str(lnurl).map_err(|_| "Invalid LNURL".to_string())?;

        Ok(Self { lnurl })
    }

    /// Get an invoice for a given amount in minor units (e.g., cents)
    #[flutter_rust_bridge::frb]
    pub async fn resolve(
        &self,
        amount_minor_units: u32,
        currency_code: String,
    ) -> Result<Invoice, String> {
        let (invoice, verify) = tokio::time::timeout(
            Duration::from_secs(5),
            resolve_amount_with_currency_code(
                self.lnurl.endpoint(),
                amount_minor_units,
                currency_code,
            ),
        )
        .await
        .map_err(|_| "Request timeout".to_string())??;

        Ok(Invoice { invoice, verify })
    }
}

#[flutter_rust_bridge::frb(opaque)]
pub struct Invoice {
    invoice: Bolt11Invoice,
    verify: String,
}

impl Invoice {
    #[flutter_rust_bridge::frb(sync)]
    pub fn raw(&self) -> String {
        self.invoice.to_string()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn amount_sats(&self) -> u32 {
        (self.invoice.amount_milli_satoshis().unwrap() / 1000) as u32
    }

    #[flutter_rust_bridge::frb]
    pub async fn verify_payment(&self) -> Result<(), String> {
        loop {
            if let Ok(response) = self.fetch_response().await {
                match response {
                    VerifyResponse::Ok(success) => {
                        if success.settled {
                            return Ok(());
                        }
                    }
                    VerifyResponse::Error(error) => return Err(error.reason.clone()),
                }
            }

            tokio::time::sleep(Duration::from_secs(1)).await;
        }
    }

    async fn fetch_response(&self) -> Result<VerifyResponse, String> {
        reqwest::get(&self.verify)
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

async fn resolve_amount_with_currency_code(
    endpoint: String,
    amount_minor_units: u32,
    currency_code: String,
) -> Result<(Bolt11Invoice, String), String> {
    let response = reqwest::get("https://price-feed.dev.fedibtc.com/latest")
        .await
        .map_err(|_| "Failed to fetch exchange rates".to_string())?
        .json::<FediPriceResponse>()
        .await
        .map_err(|_| "Failed to parse exchange rates".to_string())?;

    // Step 1: Convert minor units to major units (e.g., 1234 cents → 12.34 EUR)
    let amount_in_currency = amount_minor_units as f64 / 100.0;

    // Step 2: Convert currency to USD (via exchange rate)
    let amount_in_usd = if currency_code == "USD" {
        amount_in_currency
    } else {
        let currency_to_usd_rate = response
            .prices
            .get(&format!("{}/USD", currency_code))
            .ok_or("Selected currency not supported".to_string())?
            .rate;

        amount_in_currency * currency_to_usd_rate
    };

    // Step 3: Convert USD to BTC
    let usd_to_btc_rate = response
        .prices
        .get("BTC/USD")
        .ok_or("BTC/USD rate not found".to_string())?
        .rate;

    let amount_in_btc = amount_in_usd / usd_to_btc_rate;

    // Step 4: Convert BTC to millisatoshis (1 BTC = 100,000,000,000 msat)
    let amount_msat = (amount_in_btc * 100_000_000_000.0).round() as u64;

    let response = reqwest::get(endpoint)
        .await
        .map_err(|_| "Failed to fetch LNURL response".to_string())?
        .json::<LnUrlPayResponse>()
        .await
        .map_err(|_| "Failed to parse LNURL response".to_string())?;

    if amount_msat < response.min_sendable {
        return Err("Amount too low".to_string());
    }

    if amount_msat > response.max_sendable {
        return Err("Amount too high".to_string());
    }

    let callback_url = format!("{}?amount={}", response.callback, amount_msat);

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
