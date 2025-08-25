package handlers

import (
	"encoding/json"
	"github.com/go-playground/validator/v10"
	"moneef/internal/services"
	"moneef/pkg/utils"
	"net/http"
	"time"
)

type RegisterRequest struct {
	Username  string    `json:"username" validate:"required"`
	Password  string    `json:"password" validate:"required"`
	Name      string    `json:"name" validate:"required"`
	Birthdate time.Time `json:"birthdate"`
	Gender    string    `json:"gender"`
}

type LoginRequest struct {
	Username string `json:"username" validate:"required"`
	Password string `json:"password" validate:"required"`
}

func LoginUserHandler(w http.ResponseWriter, r *http.Request) {
	var req LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Invalid Input")
		return
	}
	validate := validator.New()
	if err := validate.Struct(req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, err.Error())
		return
	}
	_, err := services.CheckUserCredentials(req.Username, req.Password)
	if err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Wrong username or password")
		return
	}
	token, err := utils.GenerateJWT(req.Username)
	if err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, err.Error())
		return
	}
	_ = json.NewEncoder(w).Encode(map[string]string{"token": token})
}
