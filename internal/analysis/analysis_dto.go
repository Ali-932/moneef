package analysis

import (
	"github.com/shopspring/decimal"
	"time"
)

type AnalysisCharts struct {
	Categories           []CategorySummary `json:"categories"`
	CategoriesLastPeriod []CategorySummary `json:"categories_last_period"`
	Total                decimal.Decimal   `json:"total"`
	StartDate            time.Time
	EndDate              time.Time
}

type CategorySummary struct {
	CategoryID   uint            `json:"category_id"`
	CategoryName string          `json:"category_name"`
	TotalAmount  decimal.Decimal `json:"total_amount"`
	Percentage   decimal.Decimal `json:"percentage"`
}

type SpendByCategoryChartRequest struct {
	StartDate time.Time `json:"start_date" validate:"required"`
	EndDate   time.Time `json:"end_date" validate:"required,gtfield=StartDate"`
}
type SpendByCategoryChartResponse struct {
	Categories           []CategorySummary `json:"categories"`
	CategoriesLastPeriod []CategorySummary `json:"categories_last_period"`
	Total                decimal.Decimal   `json:"total"`
	StartDate            time.Time
	EndDate              time.Time
}
