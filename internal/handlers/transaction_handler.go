package handlers

import (
	"encoding/json"
	"errors"
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
	TransactionName         string            `json:"transaction_name" validate:"required"`
	ProfileId               uint              `json:"profile_id" validate:"required"`
	Amount                  decimal.Decimal   `json:"amount" validate:"required"`
	CurrencyCode            string            `json:"currency_code" validate:"required,len=3"`
	TransactionType         string            `json:"transaction_type" validate:"required,oneof=expense income"`
	Date                    time.Time         `json:"date" validate:"required"`
	Icon                    string            `json:"icon"`
	Color                   string            `json:"color"`
	MerchantName            *string           `json:"merchant_name"`
	Notes                   *string           `json:"notes"`
	IsRecurrent             *bool             `json:"is_recurrent"`
	RecurrentFreq           *string           `json:"recurrent_freq" validate:"oneof=daily weekly bi-weekly monthly yearly"`
	IsActiveRecurrent       *bool             `json:"is_active_recurrent"`
	RecurrentAmountPaid     *decimal.Decimal  `json:"recurrent_amount_paid"`
	RecurrentTotalAmount    *decimal.Decimal  `json:"recurrent_total_amount"`
	RecurrentPaidPreviously *decimal.Decimal  `json:"recurrent_paid_previously"`
	RecurrentHasEndDate     *bool             `json:"recurrent_has_end_date"`
	RecurrentEndDate        *time.Time        `json:"recurrent_end_date"`
	Categories              []CategoryRequest `json:"categories" validate:"required,min=1,dive"`
}

func (tr *TransactionRequest) Validate() error {
	validate := validator.New()
	if err := validate.Struct(tr); err != nil {
		return err
	}
	if tr.Amount.Cmp(decimal.Zero) <= 0 {
		return errors.New("amount must be greater than zero")
	}
	if tr.IsRecurrent == nil || !*tr.IsRecurrent {
		return nil
	}
	if tr.RecurrentFreq == nil {
		return errors.New("recurrent_freq is required when is_recurrent is true")
	}

	if tr.RecurrentHasEndDate != nil && *tr.RecurrentHasEndDate {
		if tr.RecurrentEndDate == nil {
			return errors.New("recurrent_end_date is required when recurrent_has_end_date is true")
		}
		if tr.RecurrentEndDate.Before(tr.Date) {
			return errors.New("recurrent_end_date cannot be before transaction date")
		}
		if tr.RecurrentTotalAmount == nil {
			return errors.New("recurrent_total_amount is required when is_recurrent is true")
		}
		if tr.RecurrentPaidPreviously == nil {
			return errors.New("recurrent_paid_previously is required when is_recurrent is true")
		}
	}

	return nil
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

	if err := req.Validate(); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, err.Error())
		return
	}
	categoryIDs := make([]uint, 0, len(req.Categories))
	for _, c := range req.Categories {
		categoryIDs = append(categoryIDs, c.ID)
	}

	if err := services.HandleTransactionCreation(services.TransactionCreationParams{
		ProfileID:            req.ProfileId,
		Name:                 req.TransactionName,
		Type:                 req.TransactionType,
		Date:                 req.Date,
		Amount:               req.Amount,
		CurrencyCode:         req.CurrencyCode,
		Icon:                 req.Icon,
		Color:                req.Color,
		MerchantName:         req.MerchantName,
		Notes:                req.Notes,
		CategoryIDs:          categoryIDs,
		IsRecurrent:          req.IsRecurrent,
		Frequency:            req.RecurrentFreq,
		AmountPaidPreviously: req.RecurrentAmountPaid,
		TotalAmountToPay:     req.RecurrentTotalAmount,
		EndDate:              req.RecurrentEndDate,
		HasEndDate:           req.RecurrentHasEndDate,
		IsActive:             req.IsActiveRecurrent,
	}); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(map[string]string{"message": "transaction created"})

}
