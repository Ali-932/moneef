package types

import (
	"database/sql/driver"
	"encoding/json"
	"github.com/shopspring/decimal"
	"moneef/internal/config"
)

type Money decimal.Decimal

// Database → Go
func (m *Money) Scan(value interface{}) error {
	d := (*decimal.Decimal)(m)
	err := d.Scan(value)
	if err != nil {
		return err
	}
	*d = d.Round(config.AmountRounding)
	return nil
}

// Go → Database
func (m *Money) Value() (driver.Value, error) {
	if m == nil {
		return nil, nil
	}
	return decimal.Decimal(*m).Value()
}

func (m *Money) MathOperation(other Money, operation func(decimal.Decimal, decimal.Decimal) decimal.Decimal) Money {
	return Money(operation(decimal.Decimal(*m), decimal.Decimal(other)))
}

func (m *Money) String() string {
	if m == nil {
		return ""
	}
	return "$" + decimal.Decimal(*m).String()
}

func (m Money) GreaterThan(other Money) bool {
	return decimal.Decimal(m).GreaterThan(decimal.Decimal(other))
}

// Simple helper methods for common operations
func (m Money) Add(other Money) Money {
	return Money(decimal.Decimal(m).Add(decimal.Decimal(other)))
}

func (m Money) Sub(other Money) Money {
	return Money(decimal.Decimal(m).Sub(decimal.Decimal(other)))
}

func (m Money) Mul(other Money) Money {
	return Money(decimal.Decimal(m).Mul(decimal.Decimal(other)))
}

func (m Money) Div(other Money) Money {
	return Money(decimal.Decimal(m).Div(decimal.Decimal(other)))
}

// Helper functions for creating Money values
func MoneyZero() Money {
	return Money(decimal.Zero)
}

func MoneyFromInt(value int64) Money {
	return Money(decimal.NewFromInt(value))
}

// JSON marshaling
func (m Money) MarshalJSON() ([]byte, error) {
	return json.Marshal(decimal.Decimal(m).String())
}

func (m *Money) UnmarshalJSON(data []byte) error {
	var str string
	if err := json.Unmarshal(data, &str); err != nil {
		return err
	}
	d, err := decimal.NewFromString(str)
	if err != nil {
		return err
	}
	*m = Money(d)
	return nil
}
