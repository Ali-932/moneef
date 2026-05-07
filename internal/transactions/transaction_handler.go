package transactions

import (
	"encoding/json"
	"errors"
	"github.com/go-chi/chi/v5"
	"github.com/shopspring/decimal"
	"log"
	"moneef/internal/models"
	"moneef/internal/transactions/dto"
	"moneef/internal/transactions/service"
	"moneef/pkg/pagination"
	"moneef/pkg/utils"
	"net/http"
	"strconv"

	"gorm.io/gorm"
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

func ListTransactionsHandler(w http.ResponseWriter, r *http.Request) {
	profileID, ok := r.Context().Value("profileID").(uint)
	if !ok {
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	q := r.URL.Query()
	txType := q.Get("type")
	categoryID, _ := strconv.ParseUint(q.Get("category_id"), 10, 64)
	dateFrom := q.Get("date_from")
	dateTo := q.Get("date_to")
	sort := q.Get("sort")

	query := service.ListTransactions(profileID, txType, uint(categoryID), dateFrom, dateTo, sort)

	result, err := pagination.Paginate[models.Transaction](query, r)
	if err != nil {
		log.Printf("❌ [HANDLER] Failed to list transactions: %v", err)
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to list transactions")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(result)
}

func GetTransactionHandler(w http.ResponseWriter, r *http.Request) {
	profileID, ok := r.Context().Value("profileID").(uint)
	if !ok {
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	transactionID, err := strconv.ParseUint(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Invalid transaction ID")
		return
	}

	transaction, err := service.GetTransaction(uint(transactionID), profileID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.WriteJsonError(w, http.StatusNotFound, "Transaction not found")
			return
		}
		log.Printf("❌ [HANDLER] Failed to get transaction: %v", err)
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to get transaction")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(transaction)
}

func UpdateTransactionHandler(w http.ResponseWriter, r *http.Request) {
	profileID, ok := r.Context().Value("profileID").(uint)
	if !ok {
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	transactionID, err := strconv.ParseUint(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Invalid transaction ID")
		return
	}

	var req dto.TransactionUpdateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Invalid Input")
		return
	}

	if err := req.Validate(); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, err.Error())
		return
	}

	categoriesMap := make(map[uint]decimal.Decimal, len(req.TransactionCategories))
	for _, c := range req.TransactionCategories {
		categoriesMap[c.CategoryId] = c.Amount
	}

	if err := service.UpdateTransaction(uint(transactionID), profileID, req, categoriesMap); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.WriteJsonError(w, http.StatusNotFound, "Transaction not found")
			return
		}
		log.Printf("❌ [HANDLER] Failed to update transaction: %v", err)
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to update transaction")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{"message": "transaction updated"})
}

func DeleteTransactionHandler(w http.ResponseWriter, r *http.Request) {
	profileID, ok := r.Context().Value("profileID").(uint)
	if !ok {
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	transactionID, err := strconv.ParseUint(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Invalid transaction ID")
		return
	}

	if err := service.DeleteTransaction(uint(transactionID), profileID); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.WriteJsonError(w, http.StatusNotFound, "Transaction not found")
			return
		}
		log.Printf("❌ [HANDLER] Failed to delete transaction: %v", err)
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to delete transaction")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
