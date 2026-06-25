package experimentation

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

// GetCompanyCompleteData يجلب جميع بيانات الشركة المتاحة بناءً على الـ ID الخاص بها فقط
func GetCompanyCompleteData(ctx context.Context, conn *pgx.Conn, companyID int) (map[string]interface{}, error) {
	finalResult := make(map[string]interface{})

	// -----------------------------------------------------------------
	// 1. التحقق من وجود الشركة وجلب رقم جوالها باستخدام الـ ID
	// -----------------------------------------------------------------
	var compPhone string
	err := conn.QueryRow(ctx, "SELECT phone_number FROM companies WHERE id = $1", companyID).Scan(&compPhone)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("❌ لا توجد شركة مسجلة بالرقم التعريفي (ID): %d", companyID)
		}
		return nil, fmt.Errorf("❌ خطأ أثناء البحث عن الشركة بواسطة ID: %v", err)
	}

	finalResult["companies"] = map[string]interface{}{
		"id":           companyID,
		"phone_number": compPhone,
	}

	// -----------------------------------------------------------------
	// 2. جلب بيانات جدول company_ai_info
	// -----------------------------------------------------------------
	var aiCompanyID int
	var aiAge string // ✅ تم التعديل إلى string لتطابق character varying(50) في القاعدة
	var aiName, nameCompany, moreInfoCompany, moreInfo string

	err = conn.QueryRow(ctx, `
		SELECT id_company, ai_name, ai_age, name_company, more_info_company, more_info 
		FROM company_ai_info WHERE id_company = $1`, companyID).Scan(&aiCompanyID, &aiName, &aiAge, &nameCompany, &moreInfoCompany, &moreInfo)

	if err != nil {
		// إذا كان الخطأ بسبب عدم وجود بيانات (جدول فارغ) نضع nil طبيعي
		// أما إذا كان خطأ آخر (مثل مشكلة أنواع) سيطبعه لك في الـ Terminal لتكتشفه فوراً
		if err != pgx.ErrNoRows {
			fmt.Printf("⚠️ تنبيه خطأ في Scan لجدول الـ AI: %v\n", err)
		}
		finalResult["company_ai_info"] = nil
	} else {
		finalResult["company_ai_info"] = map[string]interface{}{
			"id_company":        aiCompanyID,
			"ai_name":           aiName,
			"ai_age":            aiAge,
			"name_company":      nameCompany,
			"more_info_company": moreInfoCompany,
			"more_info":         moreInfo,
		}
	}

	// -----------------------------------------------------------------
	// 3. جلب بيانات جدول bot_responses
	// -----------------------------------------------------------------
	botResponses := make([]map[string]interface{}, 0)

	botRows, err := conn.Query(ctx, "SELECT id_company, keyword, response, is_active FROM bot_responses WHERE id_company = $1", companyID)
	if err == nil {
		defer botRows.Close()
		for botRows.Next() {
			var bCompanyID int
			var keyword, response string
			var isActive bool

			if err := botRows.Scan(&bCompanyID, &keyword, &response, &isActive); err == nil {
				botResponses = append(botResponses, map[string]interface{}{
					"id_company": bCompanyID,
					"keyword":    keyword,
					"response":   response,
					"is_active":  isActive,
				})
			}
		}
	}
	finalResult["bot_responses"] = botResponses

	// -----------------------------------------------------------------
	// 4. جلب بيانات جدول bookings
	// -----------------------------------------------------------------
	bookings := make([]map[string]interface{}, 0)

	bookingRows, err := conn.Query(ctx, "SELECT id_company, appointment_date, is_active, employee_id FROM bookings WHERE id_company = $1", companyID)
	if err == nil {
		defer bookingRows.Close()
		for bookingRows.Next() {
			var bkCompanyID, employeeID int
			var appointmentDate time.Time
			var isActive bool

			if err := bookingRows.Scan(&bkCompanyID, &appointmentDate, &isActive, &employeeID); err == nil {
				bookings = append(bookings, map[string]interface{}{
					"id_company":       bkCompanyID,
					"appointment_date": appointmentDate,
					"is_active":        isActive,
					"employee_id":      employeeID,
				})
			}
		}
	}
	finalResult["bookings"] = bookings

	return finalResult, nil
}

func AIname(data map[string]interface{}) string {
	var aiName string

	if aiInfo, ok := data["company_ai_info"].(map[string]interface{}); ok && aiInfo != nil {

		if name, nameOk := aiInfo["ai_name"].(string); nameOk {
			aiName = name
		}
	}

	return aiName
}

func AIage(data map[string]interface{}) string {
	var aiAge string

	if aiInfo, ok := data["company_ai_info"].(map[string]interface{}); ok && aiInfo != nil {

		if name, nameOk := aiInfo["ai_age"].(string); nameOk {
			aiAge = name
		}
	}

	return aiAge
}

func AIname_company(data map[string]interface{}) string {
	var ainame_company string

	if aiInfo, ok := data["company_ai_info"].(map[string]interface{}); ok && aiInfo != nil {

		if name, nameOk := aiInfo["name_company"].(string); nameOk {
			ainame_company = name
		}
	}

	return ainame_company
}

func AImore_info_company(data map[string]interface{}) string {
	var aiMore_Info_Company string

	if aiInfo, ok := data["company_ai_info"].(map[string]interface{}); ok && aiInfo != nil {

		if name, nameOk := aiInfo["more_info_company"].(string); nameOk {
			aiMore_Info_Company = name
		}
	}

	return aiMore_Info_Company
}

func AImore_info(data map[string]interface{}) string {
	var aiMore_Info string

	if aiInfo, ok := data["company_ai_info"].(map[string]interface{}); ok && aiInfo != nil {

		if name, nameOk := aiInfo["more_info"].(string); nameOk {
			aiMore_Info = name
		}
	}

	return aiMore_Info
}

// ----------------------------------------------------------------------------------------------
// ---------   bot_responses   -------------
//
//	keyword  ,  response  ,  is_active
//
// ------------------------------------------------------------------------------------------
func AIkeyword_bot_responses(data map[string]interface{}) string {
	var aiKeyword string

	if aiInfo, ok := data["bot_responses"].(map[string]interface{}); ok && aiInfo != nil {

		if name, nameOk := aiInfo["keyword"].(string); nameOk {
			aiKeyword = name
		}
	}

	return aiKeyword
}

func AIresponse_bot_responses(data map[string]interface{}) string {
	var aiResponse string

	if aiInfo, ok := data["bot_responses"].(map[string]interface{}); ok && aiInfo != nil {

		if name, nameOk := aiInfo["response"].(string); nameOk {
			aiResponse = name
		}
	}

	return aiResponse
}

func AIis_active_bot_responses(data map[string]interface{}) string {
	var aiIs_active string

	if aiInfo, ok := data["bot_responses"].(map[string]interface{}); ok && aiInfo != nil {

		if name, nameOk := aiInfo["is_active"].(string); nameOk {
			aiIs_active = name
		}
	}

	return aiIs_active
}

// ---------------------------------------------------
// -----------  bookings   -----------
//    appointment_date    ,    is_active    ,   employee_id
//  -------------------------------------------------------------------------

func AIappointment_date_bookings(data map[string]interface{}) string {
	var aiAppointment_date string

	if aiInfo, ok := data["bookings"].(map[string]interface{}); ok && aiInfo != nil {

		if name, nameOk := aiInfo["appointment_date"].(string); nameOk {
			aiAppointment_date = name
		}
	}

	return aiAppointment_date
}

func AIis_active_bookings(data map[string]interface{}) string {
	var aiIs_active string

	if aiInfo, ok := data["bookings"].(map[string]interface{}); ok && aiInfo != nil {

		if name, nameOk := aiInfo["is_active"].(string); nameOk {
			aiIs_active = name
		}
	}

	return aiIs_active
}

func AIemployee_id_bookings(data map[string]interface{}) string {
	var aiEmployee_id string

	if aiInfo, ok := data["bookings"].(map[string]interface{}); ok && aiInfo != nil {

		if name, nameOk := aiInfo["employee_id"].(string); nameOk {
			aiEmployee_id = name
		}
	}

	return aiEmployee_id
}
