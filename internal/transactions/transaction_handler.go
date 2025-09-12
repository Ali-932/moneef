package transactions

import (
	"encoding/json"
	"github.com/shopspring/decimal"
	"log"
	"moneef/internal/transactions/dto"
	"moneef/internal/transactions/service"
	"moneef/pkg/utils"
	"net/http"
)

func CreateTransactionHandler(w http.ResponseWriter, r *http.Request) {
	profileID, ok := r.Context().Value("profileID").(uint)
	if !ok {
		log.Printf("❌ [HANDLER] profileID not found in context")
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}
	var req dto.TransactionRequest
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

	if err := service.HandleTransactionCreation(dto.TransactionCreationParams{
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
