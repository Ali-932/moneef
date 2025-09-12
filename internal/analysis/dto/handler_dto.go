package dto

import (
	"time"
)

type SpendByCategoryChartRequest struct {
	StartDate time.Time `json:"start_date" validate:"required"`
	EndDate   time.Time `json:"end_date" validate:"required,gtfield=StartDate"`
}
type SpendByCategoryChartResponse struct {
	AnalysisCharts AnalysisCharts
	StartDate      time.Time
	EndDate        time.Time
	Currency       string
}
