//go:build android || smoke

package mobile

import "errors"

var (
	ErrNotInitialized = errors.New("mobile: Init has not been called")
	ErrAlreadyInited  = errors.New("mobile: Init has already been called")
	ErrProfileNotSet  = errors.New("mobile: profile id is not set; call SetProfileID or pass it to Init")
	ErrInvalidPayload = errors.New("mobile: invalid JSON payload")
)
