//go:build smoke

// C-shared shim that lets host-side Flutter tests drive the real Go mobile
// core over dart:ffi. Dispatch mirrors MoneefBridge.kt one-to-one so the
// Dart layer sees the same bytes/errors it gets on Android.
//
// Build: go build -tags smoke -buildmode=c-shared -o build/libmoneef_e2e.so ./mobile/_e2e/
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

	"moneef/mobile"
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
		return nil, nil, mobile.Init(a.DBPath, a.ProfileID)
	case "shutdown":
		return nil, nil, mobile.Shutdown()
	case "activeProfileId":
		v := mobile.ActiveProfileID()
		return nil, &v, nil
	case "setProfileId":
		return nil, nil, mobile.SetProfileID(a.ID)
	case "setup":
		res, err = mobile.Setup(p)
	case "createTransaction":
		res, err = mobile.CreateTransaction(p)
	case "listTransactions":
		res, err = mobile.ListTransactions(p)
	case "getTransaction":
		res, err = mobile.GetTransaction(a.ID)
	case "updateTransaction":
		res, err = mobile.UpdateTransaction(a.ID, p)
	case "deleteTransaction":
		err = mobile.DeleteTransaction(a.ID)
	case "listRecurrences":
		res, err = mobile.ListRecurrences()
	case "recurrenceTimeline":
		res, err = mobile.RecurrenceTimeline()
	case "updateRecurrence":
		err = mobile.UpdateRecurrence(a.ID, p)
	case "deleteRecurrence":
		err = mobile.DeleteRecurrence(a.ID)
	case "listCurrencies":
		res, err = mobile.ListCurrencies()
	case "listExchangeRates":
		res, err = mobile.ListExchangeRates(p)
	case "upsertExchangeRate":
		err = mobile.UpsertExchangeRate(p)
	case "fetchExchangeRates":
		err = mobile.FetchExchangeRates()
	case "listCategories":
		res, err = mobile.ListCategories(p)
	case "createCategory":
		res, err = mobile.CreateCategory(p)
	case "updateCategory":
		err = mobile.UpdateCategory(a.ID, p)
	case "deleteCategory":
		err = mobile.DeleteCategory(a.ID)
	case "dashboard":
		res, err = mobile.Dashboard(p)
	case "analysis":
		res, err = mobile.Analysis(p)
	case "patterns":
		res, err = mobile.Patterns()
	case "refreshPatterns":
		res, err = mobile.RefreshPatterns(p)
	case "getProfile":
		res, err = mobile.GetProfile()
	case "updateProfile":
		err = mobile.UpdateProfile(p)
	case "getSettings":
		res, err = mobile.GetSettings()
	case "updateSettings":
		err = mobile.UpdateSettings(p)
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
	_ = mobile.Shutdown()
	for _, s := range []string{"", "-wal", "-shm"} {
		_ = os.Remove(path + s)
	}
	if err := mobile.Init(path, 0); err != nil {
		return C.CString(err.Error())
	}
	return C.CString("")
}

//export MoneefFree
func MoneefFree(p *C.char) { C.free(unsafe.Pointer(p)) }

func main() {}
