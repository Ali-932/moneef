package handlers

import (
	"encoding/json"
	"github.com/go-playground/validator/v10"
	"github.com/shopspring/decimal"
	"moneef/internal/services"
	"moneef/pkg/utils"
	"net/http"
	"time"
)

type CategoryRequest struct {
	ID uint `json:"id" validate:"required,gt=0"`
}

type TransactionRequest struct {
	TransactionName     string            `json:"transaction_name" validate:"required"`
	ProfileId           uint              `json:"profile_id" validate:"required"`
	Amount              decimal.Decimal   `json:"amount" validate:"required"`
	CurrencyCode        string            `json:"currency_code" validate:"required,len=3"`
	TransactionType     string            `json:"transaction_type" validate:"required,oneof=expense income"`
	Date                time.Time         `json:"date" validate:"required"`
	Icon                string            `json:"icon"`
	Color               string            `json:"color"`
	MerchantName        *string           `json:"merchant_name"`
	Notes               *string           `json:"notes"`
	IsRecurrent         *bool             `json:"is_recurrent"`
	RecurrentFreq       *string           `json:"recurrent_freq"`
	RecurrentType       *string           `json:"recurrent_type"`
	IsActiveRecurrent   *bool             `json:"is_active_recurrent"`
	RecurrentAmountPaid *decimal.Decimal  `json:"recurrent_amount_paid"`
	RecurrentStartDate  *time.Time        `json:"recurrent_start_date"`
	RecurrentHasEndDate *bool             `json:"recurrent_has_end_date"`
	RecurrentEndDate    *time.Time        `json:"recurrent_end_date"`
	Categories          []CategoryRequest `json:"categories" validate:"required,min=1,dive"`
}

func CreateTransactionHandler(w http.ResponseWriter, r *http.Request) {
	var req TransactionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Invalid Input")
		return
	}
	validate := validator.New()
	if err := validate.Struct(req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, err.Error())
		return
	}
	categoryIDs := make([]uint, 0, len(req.Categories))
	for _, c := range req.Categories {
		categoryIDs = append(categoryIDs, c.ID)
	}

	if err := services.HandelTransactionCreation(
		req.ProfileId,
		req.TransactionName,
		req.Amount,
		req.CurrencyCode,
		req.TransactionType,
		req.Date,
		req.Icon,
		req.Color,
		req.MerchantName,
		req.Notes,
		categoryIDs,
		req.IsRecurrent,
		req.RecurrentFreq,
		req.RecurrentType,
		req.IsActiveRecurrent,
		req.RecurrentAmountPaid,
		req.RecurrentStartDate,
		req.RecurrentHasEndDate,
		req.RecurrentEndDate,
	); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(map[string]string{"message": "transaction created"})

}
