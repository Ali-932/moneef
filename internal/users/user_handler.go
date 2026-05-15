package users

import (
	"encoding/json"
	"net/http"

	"github.com/go-playground/validator/v10"
	"moneef/internal/users/dto"
	"moneef/internal/users/service"
	"moneef/pkg/utils"
)

func SetupHandler(w http.ResponseWriter, r *http.Request) {
	var req dto.SetupRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Invalid Input")
		return
	}
	validate := validator.New()
	if err := validate.Struct(req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, err.Error())
		return
	}

	profile, settings, err := service.Setup(req)
	if err != nil {
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to set up")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"profile":  profile,
		"settings": settings,
	})
}
