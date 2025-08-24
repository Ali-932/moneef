package types

import (
	"database/sql/driver"
	"github.com/shopspring/decimal"
)

type Money decimal.Decimal

// Database → Go
func (m *Money) Scan(value interface{}) error {
	d := (*decimal.Decimal)(m)
	return d.Scan(value)
}

// Go → Database
func (m *Money) Value() (driver.Value, error) {
	return decimal.Decimal(*m).Value()
}

func (m *Money) MathOperation(other Money, operation func(decimal.Decimal, decimal.Decimal) decimal.Decimal) Money {
	return Money(operation(decimal.Decimal(*m), decimal.Decimal(other)))
}

func (m *Money) String() string {
	return "$" + decimal.Decimal(*m).String()
}
