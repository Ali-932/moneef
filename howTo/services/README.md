# How to Create Services

## Basic Service Structure
```go
package services

import (
    "errors"
    "goMangaObserver/internal/repository"
    "goMangaObserver/internal/models"
    "gorm.io/gorm"
)

func YourService(param1 string, param2 string) (*models.YourModel, error) {
    // Validate input
    if param1 == "" {
        return nil, errors.New("param1 is required")
    }
    
    // Call repository
    result, err := repository.YourRepositoryFunction(param1, param2)
    if err != nil {
        if errors.Is(err, gorm.ErrRecordNotFound) {
            return nil, errors.New("record not found")
        }
        return nil, err
    }
    
    // Business logic processing
    if result.SomeField == "special_value" {
        // Do something special
    }
    
    return result, nil
}

func ProcessYourData(data []YourDataType) error {
    for _, item := range data {
        processed := processItem(item)
        if err := repository.SaveProcessedItem(processed); err != nil {
            continue // or handle error
        }
    }
    return nil
}

func CheckYourCondition(condition string) (bool, error) {
    result, err := repository.GetByCondition(condition)
    if err != nil {
        if errors.Is(err, gorm.ErrRecordNotFound) {
            return false, nil
        }
        return false, err
    }
    return result != nil, nil
}
```

## Service Patterns
- Input validation
- Repository calls
- Business logic
- Error handling
- Data transformation