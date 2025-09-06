package utils

import (
	"encoding/json"
	"net/http"
	"strconv"
)

func WriteJsonError(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]string{"status": strconv.Itoa(status), "error": message})
}
