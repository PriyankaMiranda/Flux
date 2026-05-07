#!/usr/bin/env python3
"""
Flux Algorithmic Engine
Runs strategy algorithms on normalized market data
"""

import json
from typing import Dict, List
from dataclasses import dataclass
import numpy as np


@dataclass
class Trade:
    exchange: str
    symbol: str
    price: float
    quantity: float
    timestamp: int


class StrategyEngine:
    """Base strategy engine for algorithmic trading"""

    def __init__(self, name: str):
        self.name = name
        self.price_history: List[float] = []

    def on_trade(self, trade: Trade) -> Dict:
        """Process incoming trade"""
        self.price_history.append(trade.price)
        
        # Keep only last 100 prices
        if len(self.price_history) > 100:
            self.price_history = self.price_history[-100:]

        signal = self.calculate_signal()
        return {
            "strategy": self.name,
            "signal": signal,
            "price": trade.price,
            "timestamp": trade.timestamp,
        }

    def calculate_signal(self) -> str:
        """Calculate trading signal based on prices"""
        if len(self.price_history) < 2:
            return "hold"

        sma_5 = np.mean(self.price_history[-5:])
        sma_20 = np.mean(self.price_history[-20:]) if len(self.price_history) >= 20 else sma_5

        if sma_5 > sma_20:
            return "buy"
        elif sma_5 < sma_20:
            return "sell"
        else:
            return "hold"


class MomentumStrategy(StrategyEngine):
    """Momentum-based trading strategy"""

    def calculate_signal(self) -> str:
        if len(self.price_history) < 3:
            return "hold"

        recent_change = (self.price_history[-1] - self.price_history[-3]) / self.price_history[-3]
        
        if recent_change > 0.02:  # 2% gain
            return "buy"
        elif recent_change < -0.02:  # 2% loss
            return "sell"
        else:
            return "hold"


class MeanReversionStrategy(StrategyEngine):
    """Mean reversion strategy"""

    def calculate_signal(self) -> str:
        if len(self.price_history) < 20:
            return "hold"

        mean = np.mean(self.price_history)
        stddev = np.std(self.price_history)
        current = self.price_history[-1]

        if current < mean - 2 * stddev:
            return "buy"
        elif current > mean + 2 * stddev:
            return "sell"
        else:
            return "hold"


if __name__ == "__main__":
    # Example usage
    momentum = MomentumStrategy("momentum")
    mean_reversion = MeanReversionStrategy("mean_reversion")

    print("Flux Strategy Engine initialized")
    print(f"Strategy 1: {momentum.name}")
    print(f"Strategy 2: {mean_reversion.name}")
