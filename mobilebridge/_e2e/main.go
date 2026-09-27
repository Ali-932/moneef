//go:build smoke

// C-shared shim that lets host-side Flutter tests drive the real Go mobile
// core over dart:ffi. Dispatch mirrors MoneefBridge.kt one-to-one so the
// Dart layer sees the same bytes/errors it gets on Android.
//
// Build: go build -tags smoke -buildmode=c-shared -o build/libmoneef_e2e.so ./mobilebridge/_e2e/
package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"unsafe"

	"moneef/mobilebridge"
)

type args struct {
	DBPath    string  `json:"dbPath"`
	ProfileID int64   `json:"profileId"`
	ID        int64   `json:"id"`
	Payload   *string `json:"payload"` // base64
}

type reply struct {
	OK    bool    `json:"ok"`
	Bytes *string `json:"bytes,omitempty"` // base64 []byte result
	Int   *int64  `json:"int,omitempty"`
	Error string  `json:"error,omitempty"`
}

func dispatch(method string, a args) (res []byte, n *int64, err error) {
	var p []byte
	if a.Payload != nil {
		p, _ = base64.StdEncoding.DecodeString(*a.Payload)
	}
	switch method {
	case "init":
		return nil, nil, mobilebridge.Init(a.DBPath, a.ProfileID)
	case "shutdown":
		return nil, nil, mobilebridge.Shutdown()
	case "activeProfileId":
		v := mobilebridge.ActiveProfileID()
		return nil, &v, nil
	case "setProfileId":
		return nil, nil, mobilebridge.SetProfileID(a.ID)
	case "setup":
		res, err = mobilebridge.Setup(p)
	case "createTransaction":
		res, err = mobilebridge.CreateTransaction(p)
	case "listTransactions":
		res, err = mobilebridge.ListTransactions(p)
	case "getTransaction":
		res, err = mobilebridge.GetTransaction(a.ID)
	case "updateTransaction":
		res, err = mobilebridge.UpdateTransaction(a.ID, p)
	case "deleteTransaction":
		err = mobilebridge.DeleteTransaction(a.ID)
	case "listRecurrences":
		res, err = mobilebridge.ListRecurrences()
	case "recurrenceTimeline":
		res, err = mobilebridge.RecurrenceTimeline()
	case "updateRecurrence":
		err = mobilebridge.UpdateRecurrence(a.ID, p)
	case "deleteRecurrence":
		err = mobilebridge.DeleteRecurrence(a.ID)
	case "listCurrencies":
		res, err = mobilebridge.ListCurrencies()
	case "listExchangeRates":
		res, err = mobilebridge.ListExchangeRates(p)
	case "upsertExchangeRate":
		err = mobilebridge.UpsertExchangeRate(p)
	case "fetchExchangeRates":
		err = mobilebridge.FetchExchangeRates()
	case "listCategories":
		res, err = mobilebridge.ListCategories(p)
	case "createCategory":
		res, err = mobilebridge.CreateCategory(p)
	case "updateCategory":
		err = mobilebridge.UpdateCategory(a.ID, p)
	case "deleteCategory":
		err = mobilebridge.DeleteCategory(a.ID)
	case "dashboard":
		res, err = mobilebridge.Dashboard(p)
	case "analysis":
		res, err = mobilebridge.Analysis(p)
	case "patterns":
		res, err = mobilebridge.Patterns()
	case "refreshPatterns":
		res, err = mobilebridge.RefreshPatterns(p)
	case "getProfile":
		res, err = mobilebridge.GetProfile()
	case "updateProfile":
		err = mobilebridge.UpdateProfile(p)
	case "getSettings":
		res, err = mobilebridge.GetSettings()
	case "updateSettings":
		err = mobilebridge.UpdateSettings(p)
	default:
		err = fmt.Errorf("notImplemented: %s", method)
	}
	return res, nil, err
}

//export MoneefCall
func MoneefCall(cMethod, cArgs *C.char) *C.char {
	var a args
	_ = json.Unmarshal([]byte(C.GoString(cArgs)), &a)
	var r reply
	func() {
		defer func() {
			if p := recover(); p != nil {
				r = reply{Error: fmt.Sprintf("panic: %v", p)}
			}
		}()
		res, n, err := dispatch(C.GoString(cMethod), a)
		if err != nil {
			r = reply{Error: err.Error()}
			return
		}
		r.OK, r.Int = true, n
		if res != nil {
			s := base64.StdEncoding.EncodeToString(res)
			r.Bytes = &s
		}
	}()
	out, _ := json.Marshal(r)
	return C.CString(string(out))
}

// MoneefReset wipes the DB file and re-inits at the same path (config is a
// sync.Once singleton, so the path must stay fixed per process).
//
//export MoneefReset
func MoneefReset(cPath *C.char) *C.char {
	path := C.GoString(cPath)
	_ = mobilebridge.Shutdown()
	for _, s := range []string{"", "-wal", "-shm"} {
		_ = os.Remove(path + s)
	}
	if err := mobilebridge.Init(path, 0); err != nil {
		return C.CString(err.Error())
	}
	return C.CString("")
}

//export MoneefFree
func MoneefFree(p *C.char) { C.free(unsafe.Pointer(p)) }

func main() {}
