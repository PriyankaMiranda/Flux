use rustler::atoms;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug)]
pub struct TradeData {
    pub price: f64,
    pub quantity: f64,
    pub timestamp: i64,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct IndicatorResult {
    pub price: f64,
    pub quantity: f64,
    pub volume_weighted_price: f64,
    pub momentum: f64,
    pub volatility: f64,
}

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[rustler::nif]
pub fn calculate_indicators(price: f64, quantity: f64) -> Result<IndicatorResult, String> {
    if price <= 0.0 || quantity <= 0.0 {
        return Err("Price and quantity must be positive".to_string());
    }

    let volume_weighted_price = price * quantity;
    let momentum = calculate_momentum(price, quantity);
    let volatility = calculate_volatility(price);

    Ok(IndicatorResult {
        price,
        quantity,
        volume_weighted_price,
        momentum,
        volatility,
    })
}

fn calculate_momentum(price: f64, quantity: f64) -> f64 {
    // Simplified momentum calculation
    (price * quantity).sqrt()
}

fn calculate_volatility(price: f64) -> f64 {
    // Simplified volatility calculation
    // In real scenario, this would use historical data
    (price * 0.01).abs()
}

#[rustler::nif]
pub fn process_price_stream(prices: Vec<f64>) -> Result<StreamMetrics, String> {
    if prices.is_empty() {
        return Err("Empty price stream".to_string());
    }

    let mean = prices.iter().sum::<f64>() / prices.len() as f64;
    let variance = prices
        .iter()
        .map(|p| (p - mean).powi(2))
        .sum::<f64>()
        / prices.len() as f64;
    let stddev = variance.sqrt();

    Ok(StreamMetrics {
        mean,
        stddev,
        min: prices.iter().copied().fold(f64::INFINITY, f64::min),
        max: prices.iter().copied().fold(f64::NEG_INFINITY, f64::max),
        count: prices.len(),
    })
}

#[derive(Serialize, Deserialize, Debug)]
pub struct StreamMetrics {
    pub mean: f64,
    pub stddev: f64,
    pub min: f64,
    pub max: f64,
    pub count: usize,
}

rustler::init!("Elixir.Flux.Native", [calculate_indicators, process_price_stream]);
