package engine

import (
	"log"
	"moneef/internal/db"
	"moneef/internal/models"
	"strings"
)

func ResolveMerchantIcon(transactionID uint) {
	var transaction models.Transaction
	if err := db.DB.Preload("TransactionCategory.Category").First(&transaction, transactionID).Error; err != nil {
		log.Printf("⚠️ [ENGINE] Transaction %d not found for icon resolution: %v", transactionID, err)
		return
	}

	if transaction.Icon != "" && transaction.Color != "" {
		log.Printf("⏭️ [ENGINE] Transaction %d already has icon/color, skipping", transactionID)
		return
	}

	fields := []string{}
	if transaction.MerchantName != nil && *transaction.MerchantName != "" {
		fields = append(fields, *transaction.MerchantName)
	}
	if transaction.Name != "" {
		fields = append(fields, transaction.Name)
	}
	if transaction.Notes != nil && *transaction.Notes != "" {
		fields = append(fields, *transaction.Notes)
	}

	var iconLookup models.IconLookup
	for _, field := range fields {
		lowerField := strings.ToLower(field)
		if err := db.DB.Where("? LIKE '%' || keyword || '%'", lowerField).First(&iconLookup).Error; err == nil {
			updates := map[string]interface{}{}
			if transaction.Icon == "" {
				updates["icon"] = iconLookup.Icon
			}
			if transaction.Color == "" {
				updates["color"] = iconLookup.Color
			}
			if len(updates) > 0 {
				if err := db.DB.Model(&models.Transaction{}).Where("id = ?", transactionID).Updates(updates).Error; err != nil {
					log.Printf("❌ [ENGINE] Failed to update transaction %d icon/color: %v", transactionID, err)
					return
				}
				log.Printf("✅ [ENGINE] Transaction %d matched keyword '%s' → icon=%s color=%s", transactionID, iconLookup.Keyword, iconLookup.Icon, iconLookup.Color)
			}
			return
		}
	}

	if len(transaction.TransactionCategory) > 0 {
		cat := transaction.TransactionCategory[0].Category
		updates := map[string]interface{}{}
		if transaction.Icon == "" && cat.Icon != "" {
			updates["icon"] = cat.Icon
		}
		if transaction.Color == "" && cat.Color != "" {
			updates["color"] = cat.Color
		}
		if len(updates) > 0 {
			if err := db.DB.Model(&models.Transaction{}).Where("id = ?", transactionID).Updates(updates).Error; err != nil {
				log.Printf("❌ [ENGINE] Failed to update transaction %d with category fallback: %v", transactionID, err)
				return
			}
			log.Printf("✅ [ENGINE] Transaction %d fell back to category '%s' icon/color", transactionID, cat.Name)
		}
	}
}

func ResolveMerchantIconAsync(transactionID uint) {
	go ResolveMerchantIcon(transactionID)
}

func ResolveCategoryIcon(categoryID uint) {
	var category models.Category
	if err := db.DB.First(&category, categoryID).Error; err != nil {
		log.Printf("⚠️ [ENGINE] Category %d not found for icon resolution: %v", categoryID, err)
		return
	}

	if category.Icon != "" && category.Color != "" {
		return
	}

	updates := map[string]interface{}{}

	var iconLookup models.IconLookup
	lowerName := strings.ToLower(category.Name)
	if err := db.DB.Where("? LIKE '%' || keyword || '%'", lowerName).First(&iconLookup).Error; err == nil {
		if category.Icon == "" {
			updates["icon"] = iconLookup.Icon
		}
		if category.Color == "" {
			updates["color"] = iconLookup.Color
		}
		log.Printf("✅ [ENGINE] Category %d matched keyword → icon=%s color=%s", categoryID, iconLookup.Icon, iconLookup.Color)
	} else {
		if category.Icon == "" {
			updates["icon"] = "📦"
		}
		if category.Color == "" {
			updates["color"] = "#6B5CE7"
		}
		log.Printf("✅ [ENGINE] Category %d used default icon/color", categoryID)
	}

	if len(updates) > 0 {
		if err := db.DB.Model(&models.Category{}).Where("id = ?", categoryID).Updates(updates).Error; err != nil {
			log.Printf("❌ [ENGINE] Failed to update category %d icon/color: %v", categoryID, err)
		}
	}
}

func ResolveCategoryIconAsync(categoryID uint) {
	go ResolveCategoryIcon(categoryID)
}
