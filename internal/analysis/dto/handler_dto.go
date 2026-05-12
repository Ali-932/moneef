package dto

import (
	"time"
)

type SpendByCategoryChartRequest struct {
	StartDate time.Time `json:"start_date" validate:"required"`
	EndDate   time.Time `json:"end_date" validate:"required,gtfield=StartDate"`
}

type AggregatedPeriod struct {
	Label       string    `json:"label"`
	Amount      string    `json:"amount"`
	PeriodStart time.Time `json:"period_start"`
	PeriodEnd   time.Time `json:"period_end"`
}

type SpendByCategoryChartResponse struct {
	AnalysisCharts AnalysisCharts     `json:"AnalysisCharts"`
	StartDate      time.Time          `json:"start_date"`
	EndDate        time.Time          `json:"end_date"`
	Currency       string             `json:"currency"`
	Aggregated     []AggregatedPeriod `json:"aggregated,omitempty"`
}
