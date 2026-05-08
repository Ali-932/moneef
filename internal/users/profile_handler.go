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

func GetProfileHandler(w http.ResponseWriter, r *http.Request) {
	profileID, ok := r.Context().Value("profileID").(uint)
	if !ok {
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}
	userID, ok := r.Context().Value("id").(uint)
	if !ok {
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	profile, err := service.GetProfile(profileID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.WriteJsonError(w, http.StatusNotFound, "Profile not found")
			return
		}
		log.Printf("❌ [HANDLER] Failed to get profile: %v", err)
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to get profile")
		return
	}

	// Fetch user to get email/birthday
	user, err := service.GetUserByID(userID)
	if err != nil {
		log.Printf("❌ [HANDLER] Failed to get user: %v", err)
		user = nil
	}

	res := dto.ProfileResponse{
		ID:        profile.ID,
		FirstName: profile.FirstName,
		LastName:  profile.LastName,
	}
	if user != nil {
		res.Email = user.Email
		res.Birthday = user.Birthday
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(res)
}

func UpdateProfileHandler(w http.ResponseWriter, r *http.Request) {
	profileID, ok := r.Context().Value("profileID").(uint)
	if !ok {
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var req dto.UpdateProfileRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Invalid Input")
		return
	}
	validate := validator.New()
	if err := validate.Struct(req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, err.Error())
		return
	}

	if err := service.UpdateProfile(profileID, req); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.WriteJsonError(w, http.StatusNotFound, "Profile not found")
			return
		}
		log.Printf("❌ [HANDLER] Failed to update profile: %v", err)
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to update profile")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{"message": "profile updated"})
}
