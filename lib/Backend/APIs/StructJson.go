package apis

type User struct {
	UserID   string `json:"userID"`
	Username string `json:"username"`
	Password string `json:"password"` // أضفنا الباسورد لكي يمر للكويري
}

type Add_Post struct {
	UserID   string `json:"userID"`
	Username string `json:"username"`
	Title    string `json:"title"`   // تم تعديل الحرف الأول إلى Capital
	Content  string `json:"content"` // تم تعديل الحرف الأول إلى Capital
}

type Get_Post struct {
	UserID   string `json:"userID"`
	Username string `json:"username"`
	Title    string `json:"title"`   // تم تعديل الحرف الأول إلى Capital
	Content  string `json:"content"` // تم تعديل الحرف الأول إلى Capital
}

type PostsResponse struct {
	UserID   string     `json:"userID"`
	Username string     `json:"username"`
	Posts    []Get_Post `json:"posts"`
}
