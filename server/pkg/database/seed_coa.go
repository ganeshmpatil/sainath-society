package database

import (
	"log"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"aangan/internal/models"
)

// ensureDefaultChartOfAccounts seeds the standard housing society chart of accounts.
// Safe to run on already-seeded DBs — checks for existing records.
func ensureDefaultChartOfAccounts(db *gorm.DB) {
	var count int64
	db.Model(&models.AccountHead{}).Count(&count)
	if count > 0 {
		return
	}

	log.Println("Seeding default Chart of Accounts...")

	// Helper to create an account and return its ID
	create := func(code, name, nameMr string, accType models.AccountType, parentID *uuid.UUID, isGroup bool) uuid.UUID {
		ah := &models.AccountHead{
			Code:     code,
			Name:     name,
			NameMr:   nameMr,
			Type:     accType,
			ParentID: parentID,
			IsGroup:  isGroup,
			IsActive: true,
			IsSystem: true,
		}
		if err := db.Create(ah).Error; err != nil {
			log.Printf("Failed to seed account %s: %v", code, err)
		}
		return ah.ID
	}

	// ═══════════════════ ASSETS ═══════════════════
	assets := create("1000", "Assets", "मालमत्ता", models.AccountAsset, nil, true)

	bankAccounts := create("1100", "Bank Accounts", "बँक खाती", models.AccountAsset, &assets, true)
	create("1101", "SBI Savings Account", "SBI बचत खाते", models.AccountAsset, &bankAccounts, false)
	create("1102", "SBI Current Account", "SBI चालू खाते", models.AccountAsset, &bankAccounts, false)

	create("1200", "Cash in Hand", "रोख रक्कम", models.AccountAsset, &assets, false)

	fixedDeposits := create("1300", "Fixed Deposits", "मुदत ठेवी", models.AccountAsset, &assets, true)
	create("1301", "Sinking Fund FD", "बुडीत निधी मुदत ठेव", models.AccountAsset, &fixedDeposits, false)
	create("1302", "Repair Fund FD", "दुरुस्ती निधी मुदत ठेव", models.AccountAsset, &fixedDeposits, false)

	receivables := create("1400", "Outstanding Receivables", "थकबाकी प्राप्ती", models.AccountAsset, &assets, true)
	create("1401", "Member Maintenance Receivable", "सदस्य देखभाल प्राप्ती", models.AccountAsset, &receivables, false)
	create("1402", "Interest Receivable", "व्याज प्राप्ती", models.AccountAsset, &receivables, false)

	fixedAssets := create("1500", "Fixed Assets", "स्थिर मालमत्ता", models.AccountAsset, &assets, true)
	create("1501", "Lift Equipment", "लिफ्ट उपकरणे", models.AccountAsset, &fixedAssets, false)
	create("1502", "Generator", "जनरेटर", models.AccountAsset, &fixedAssets, false)
	create("1503", "CCTV & Security Equipment", "सीसीटीव्ही व सुरक्षा उपकरणे", models.AccountAsset, &fixedAssets, false)
	create("1504", "Water Pump & Motor", "पाण्याचा पंप व मोटर", models.AccountAsset, &fixedAssets, false)
	create("1505", "Furniture & Fixtures", "फर्निचर व फिक्स्चर", models.AccountAsset, &fixedAssets, false)

	// ═══════════════════ LIABILITIES ═══════════════════
	liabilities := create("2000", "Liabilities", "दायित्वे", models.AccountLiability, nil, true)

	payables := create("2100", "Outstanding Payables", "थकबाकी देय", models.AccountLiability, &liabilities, true)
	create("2101", "Vendor Payable", "विक्रेता देय", models.AccountLiability, &payables, false)
	create("2102", "Salary Payable", "वेतन देय", models.AccountLiability, &payables, false)

	create("2200", "Advance Maintenance Received", "आगाऊ देखभाल प्राप्त", models.AccountLiability, &liabilities, false)
	create("2300", "Security Deposits Held", "सुरक्षा ठेवी", models.AccountLiability, &liabilities, false)

	taxPayables := create("2400", "Tax Payables", "कर देय", models.AccountLiability, &liabilities, true)
	create("2401", "TDS Payable - 194C", "TDS देय - 194C", models.AccountLiability, &taxPayables, false)
	create("2402", "TDS Payable - 194J", "TDS देय - 194J", models.AccountLiability, &taxPayables, false)
	create("2403", "TDS Payable - 194I", "TDS देय - 194I", models.AccountLiability, &taxPayables, false)
	create("2404", "GST Output Liability", "GST आउटपुट दायित्व", models.AccountLiability, &taxPayables, false)

	// ═══════════════════ INCOME ═══════════════════
	income := create("3000", "Income", "उत्पन्न", models.AccountIncome, nil, true)

	create("3101", "Maintenance Income", "देखभाल उत्पन्न", models.AccountIncome, &income, false)
	create("3102", "Non-Occupancy Charges", "अनिवासी शुल्क", models.AccountIncome, &income, false)
	create("3103", "Parking Income", "पार्किंग उत्पन्न", models.AccountIncome, &income, false)
	create("3104", "Hall Booking Income", "हॉल बुकिंग उत्पन्न", models.AccountIncome, &income, false)
	create("3105", "Interest on FD", "मुदत ठेवीवर व्याज", models.AccountIncome, &income, false)
	create("3106", "Late Payment Interest", "उशीरा भरणा व्याज", models.AccountIncome, &income, false)
	create("3107", "Transfer Premium", "हस्तांतरण प्रीमियम", models.AccountIncome, &income, false)
	create("3108", "Miscellaneous Income", "विविध उत्पन्न", models.AccountIncome, &income, false)

	// ═══════════════════ EXPENSES ═══════════════════
	expenses := create("4000", "Expenses", "खर्च", models.AccountExpense, nil, true)

	staffExpenses := create("4100", "Staff & Security", "कर्मचारी व सुरक्षा", models.AccountExpense, &expenses, true)
	create("4101", "Staff Salaries", "कर्मचारी वेतन", models.AccountExpense, &staffExpenses, false)
	create("4102", "Security Services", "सुरक्षा सेवा", models.AccountExpense, &staffExpenses, false)

	utilityExpenses := create("4200", "Utilities", "उपयोगिता खर्च", models.AccountExpense, &expenses, true)
	create("4201", "Common Area Electricity", "सामायिक वीज", models.AccountExpense, &utilityExpenses, false)
	create("4202", "Water & Sewerage", "पाणी व सांडपाणी", models.AccountExpense, &utilityExpenses, false)

	maintenanceExpenses := create("4300", "Maintenance & Repairs", "देखभाल व दुरुस्ती", models.AccountExpense, &expenses, true)
	create("4301", "Lift AMC", "लिफ्ट AMC", models.AccountExpense, &maintenanceExpenses, false)
	create("4302", "Generator AMC & Fuel", "जनरेटर AMC व इंधन", models.AccountExpense, &maintenanceExpenses, false)
	create("4303", "General Repairs", "सामान्य दुरुस्ती", models.AccountExpense, &maintenanceExpenses, false)
	create("4304", "Plumbing Repairs", "प्लंबिंग दुरुस्ती", models.AccountExpense, &maintenanceExpenses, false)
	create("4305", "Painting & Civil Work", "रंगकाम व बांधकाम", models.AccountExpense, &maintenanceExpenses, false)

	adminExpenses := create("4400", "Administrative Expenses", "प्रशासकीय खर्च", models.AccountExpense, &expenses, true)
	create("4401", "Audit & Professional Fees", "लेखापरीक्षण व व्यावसायिक शुल्क", models.AccountExpense, &adminExpenses, false)
	create("4402", "Insurance Premium", "विमा प्रीमियम", models.AccountExpense, &adminExpenses, false)
	create("4403", "Printing & Stationery", "छपाई व लेखनसामग्री", models.AccountExpense, &adminExpenses, false)
	create("4404", "Bank Charges", "बँक शुल्क", models.AccountExpense, &adminExpenses, false)
	create("4405", "Legal Expenses", "कायदेशीर खर्च", models.AccountExpense, &adminExpenses, false)
	create("4406", "Miscellaneous Expenses", "विविध खर्च", models.AccountExpense, &adminExpenses, false)

	create("4501", "Depreciation", "घसारा", models.AccountExpense, &expenses, false)

	// ═══════════════════ FUNDS ═══════════════════
	funds := create("5000", "Funds & Reserves", "निधी व राखीव", models.AccountFund, nil, true)

	create("5101", "Sinking Fund", "बुडीत निधी", models.AccountFund, &funds, false)
	create("5102", "Repair Fund", "दुरुस्ती निधी", models.AccountFund, &funds, false)
	create("5103", "Education Fund", "शिक्षण निधी", models.AccountFund, &funds, false)
	create("5104", "Welfare Fund", "कल्याण निधी", models.AccountFund, &funds, false)
	create("5105", "General Reserve", "सामान्य राखीव", models.AccountFund, &funds, false)
	create("5106", "Surplus / Deficit", "अधिशेष / तूट", models.AccountFund, &funds, false)

	log.Println("Seeded default Chart of Accounts (housing society standard)")
}
