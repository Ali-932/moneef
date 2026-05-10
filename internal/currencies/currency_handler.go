package currencies

import (
	"encoding/json"
	"moneef/pkg/utils"
	"net/http"
)

func ListCurrenciesHandler(w http.ResponseWriter, r *http.Request) {
	list, err := ListCurrencies()
	if err != nil {
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to list currencies")
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(list)
}
