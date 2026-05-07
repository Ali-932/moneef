package auth

import (
	"encoding/json"
	"github.com/go-playground/validator/v10"
	"moneef/internal/auth/dto"
	"moneef/internal/auth/service"
	"moneef/pkg/utils"
	"net/http"
)

func LoginUserHandler(w http.ResponseWriter, r *http.Request) {
	var req dto.LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Invalid Input")
		return
	}
	validate := validator.New()
	if err := validate.Struct(req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, err.Error())
		return
	}
	_, err := service.CheckUserCredentials(req.Email, req.Password)
	if err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Wrong email or password")
		return
	}
	token, err := GenerateJWT(req.Email)
	if err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, err.Error())
		return
	}
	_ = json.NewEncoder(w).Encode(map[string]string{"token": token})
}
