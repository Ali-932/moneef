package users

import (
	"encoding/json"
	"errors"
	"github.com/go-playground/validator/v10"
	"log"
	"moneef/internal/users/dto"
	"moneef/internal/users/service"
	"moneef/pkg/utils"
	"net/http"

	"gorm.io/gorm"
)

func GetSettingsHandler(w http.ResponseWriter, r *http.Request) {
	userID, ok := r.Context().Value("id").(uint)
	if !ok {
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	settings, err := service.GetSettings(userID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.WriteJsonError(w, http.StatusNotFound, "Settings not found")
			return
		}
		log.Printf("❌ [HANDLER] Failed to get settings: %v", err)
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to get settings")
		return
	}

	res := dto.SettingsResponse{
		CurrencyCode:          settings.CurrencyCode,
		Language:              settings.Language,
		IsNotificationEnabled: settings.IsNotificationEnabled,
		IsDarkMode:            settings.IsDarkMode,
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(res)
}

func UpdateSettingsHandler(w http.ResponseWriter, r *http.Request) {
	userID, ok := r.Context().Value("id").(uint)
	if !ok {
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var req dto.UpdateSettingsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Invalid Input")
		return
	}
	validate := validator.New()
	if err := validate.Struct(req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, err.Error())
		return
	}

	if err := service.UpdateSettings(userID, req); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.WriteJsonError(w, http.StatusNotFound, "Settings not found")
			return
		}
		log.Printf("❌ [HANDLER] Failed to update settings: %v", err)
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to update settings")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{"message": "settings updated"})
}
