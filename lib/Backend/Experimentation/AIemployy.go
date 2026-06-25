package experimentation

/*



import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/jackc/pgx/v5"
	"github.com/joho/godotenv"
	"google.golang.org/genai"
)

func getapi(filename string) string {
	_ = godotenv.Load()

	apikey := os.Getenv(filename)
	return apikey
}

func AIemployye(userInput string ,idCompany int ,  conn *pgx.Conn) (string, error) {
	ctx := context.Background()

	client, err := genai.NewClient(ctx, &genai.ClientConfig{
		APIKey: getapi("AIEMP")})

	if err != nil {
		log.Printf("Error AIemloyee : %v", err)
		return "", err
	}

	//----------------------------------------------------------------------------------------Get Info  for AI
	data , err := GetCompanyCompleteData(ctx , conn , idCompany); if err !=nil{log.Printf("Error func GetCompanyCompleteData : %v " , err)}
name := AIname(data)
age := AIage(data)
nameCompany := AIname_company(data)
infoCompany := AImore_info_company(data)
moreInfo := AImore_info(data)
botResponses := AIresponse_bot_responses(data)
appointmentDate := AIappointment_date_bookings(data)
employeeId_Bookings := AIemployee_id_bookings(data)
keywardBot := AIkeyword_bot_responses(data)
isActiveBooking := AIis_active_bookings(data)
isActiveResponses := AIis_active_bot_responses(data)
// ----------------------------------------------------------------------------------
text_1 := fmt.Sprintf("1- your name : %v and you are support coustmer your age : %v" , name,age)
text_2 := fmt.Sprintf("2- your work in : %v , must your : %v , info for company : %v",nameCompany , moreInfo , infoCompany)
text_3 := fmt.Sprint("3- more detials for company , bot response : %v , is active response : %v  appointement Data :%v , employee id booking : %v , keyward bot : %v ,is active booking : %v ")
	config := &genai.GenerateContentConfig{
		SystemInstruction: &genai.Content{
			Parts: []*genai.Part{
				{Text: "1. أنت موظف خدمة عملاء اسمك خالد الحربي."},
				{Text: "2. تعمل في شركة المسافر للسياحة والسفر."},
				{Text: "3. ممنوع نهائياً كتابة كلام كثير، إجاباتك يجب أن تكون مختصرة جداً ومباشرة."},
				{Text: "4. أجب دائماً بأسلوب احترافي وودّي يناسب عملاء السياحة والسفر."},
			},
		},
	}

	//--------------------------------------------------------------------------------

	chat, err := client.Chats.Create(ctx, "gemini-2.5-flash-lite", config, nil)

	if err != nil {
		log.Printf("Error Send& result AI : %v", err)
	}

	result, err := chat.SendMessage(ctx, genai.Part{Text: userInput})

	if err != nil {
		log.Printf("Error Send& result AI : %v", err)
	}

	return result.Text(), nil

}



*/
