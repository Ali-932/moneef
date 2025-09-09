package transactions

import (
	"encoding/json"
	"errors"
	"github.com/go-playground/validator/v10"
	"github.com/shopspring/decimal"
	"log"
	"moneef/pkg/utils"
	"net/http"
	"time"
)

type TransactionCategoryRequest struct {
	CategoryId uint            `json:"category_id" validate:"required,gt=0"`
	Amount     decimal.Decimal `json:"amount" validate:"required"`
}

type TransactionRequest struct {
	TransactionName         string                       `json:"transaction_name" validate:"required"`
	CurrencyCode            string                       `json:"currency_code" validate:"required,len=3"`
	TransactionType         string                       `json:"transaction_type" validate:"required,oneof=expense income"`
	Date                    time.Time                    `json:"date" validate:"required"`
	Icon                    string                       `json:"icon"`
	Color                   string                       `json:"color"`
	MerchantName            *string                      `json:"merchant_name"`
	Notes                   *string                      `json:"notes"`
	IsRecurrent             *bool                        `json:"is_recurrent"`
	RecurrentFreq           *string                      `json:"recurrent_freq" validate:"omitempty,oneof=daily weekly bi-weekly monthly yearly"`
	IsActiveRecurrent       *bool                        `json:"is_active_recurrent"`
	RecurrentTotalAmount    *decimal.Decimal             `json:"recurrent_total_amount"`
	RecurrentPaidPreviously *decimal.Decimal             `json:"recurrent_paid_previously"`
	RecurrentHasEndDate     *bool                        `json:"recurrent_has_end_date"`
	RecurrentEndDate        *time.Time                   `json:"recurrent_end_date"`
	TransactionCategories   []TransactionCategoryRequest `json:"transaction_categories" validate:"required,min=1,dive"`
}

func (tr *TransactionRequest) Validate() error {
	validate := validator.New()

	if err := validate.Struct(tr); err != nil {
		return err
	}
	seenCategories := make(map[uint]bool)
	for _, c := range tr.TransactionCategories {
		if seenCategories[c.CategoryId] {
			return errors.New("duplicate category_id found in transaction_categories")
		}
		seenCategories[c.CategoryId] = true

		if c.Amount.IsZero() {
			return errors.New("amount must be greater than zero in transaction_categories")
		}
		if c.Amount.IsNegative() {
			return errors.New("amount must be a positive value in transaction_categories")
		}
	}

	if tr.IsRecurrent != nil && *tr.IsRecurrent {
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
			if tr.RecurrentTotalAmount.IsNegative() || tr.RecurrentTotalAmount.IsZero() {
				return errors.New("recurrent_total_amount must be greater than zero")
			}
			if tr.RecurrentPaidPreviously.IsNegative() {
				return errors.New("recurrent_paid_previously cannot be negative")
			}
			if tr.RecurrentPaidPreviously.GreaterThan(*tr.RecurrentTotalAmount) {
				return errors.New("recurrent_paid_previously cannot be greater than recurrent_total_amount")
			}
		}

	}

	return nil
}

func CreateTransactionHandler(w http.ResponseWriter, r *http.Request) {
	profileID, ok := r.Context().Value("profileID").(uint)
	if !ok {
		log.Printf("❌ [HANDLER] profileID not found in context")
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}
	var req TransactionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		log.Printf("❌ [HANDLER] Failed to decode request body: %v", err)
		utils.WriteJsonError(w, http.StatusBadRequest, "Invalid Input")
		return
	}

	if err := req.Validate(); err != nil {
		log.Printf("❌ [HANDLER] Custom validation failed: %v", err)
		utils.WriteJsonError(w, http.StatusBadRequest, err.Error())
		return
	}

	CategoriesTransaction := make(map[uint]decimal.Decimal, len(req.TransactionCategories))
	for _, c := range req.TransactionCategories {
		CategoriesTransaction[c.CategoryId] = c.Amount
	}

	if err := HandleTransactionCreation(TransactionCreationParams{
		ProfileID:             profileID,
		Name:                  req.TransactionName,
		Type:                  req.TransactionType,
		Date:                  req.Date,
		CurrencyCode:          req.CurrencyCode,
		Icon:                  req.Icon,
		Color:                 req.Color,
		MerchantName:          req.MerchantName,
		Notes:                 req.Notes,
		CategoriesTransaction: CategoriesTransaction,
		IsRecurrent:           req.IsRecurrent,
		Frequency:             req.RecurrentFreq,
		AmountPaidPreviously:  req.RecurrentPaidPreviously,
		TotalAmountToPay:      req.RecurrentTotalAmount,
		EndDate:               req.RecurrentEndDate,
		HasEndDate:            req.RecurrentHasEndDate,
		IsActive:              req.IsActiveRecurrent,
	}); err != nil {
		log.Printf("❌ [HANDLER] Service layer failed: %v", err)
		utils.WriteJsonError(w, http.StatusBadRequest, err.Error())
		return
	}

	log.Printf("✅ [HANDLER] Transaction '%s' created successfully", req.TransactionName)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(map[string]string{"message": "transaction created"})

}
