package apis

import (
	"github.com/gin-gonic/gin"

	database "backendathar/database"
)

func RouterAPI(queries *database.Queries) *gin.Engine {
	r := gin.Default()

	handlerUser := NewUserHandler(queries)
	handlerPost := NewPostHandler(queries)
	handlerFollow := NewFollowHandler(queries)
	handlerChat := NewChatHandler(queries) // يغطي الغرف + الرسائل معاً (بدل تكرار نفس الـ handler باسمين)
	handlerComment := NewCommentHandler(queries)
	handlerReaction := NewReactionHandler(queries)

	// u: this for users only
	r.POST("api/v0/users/add", handlerUser.AddUser)                         // مفتوح للعامة (إنشاء حساب جديد)
	r.POST("api/v0/users/update", AuthMiddleware(), handlerUser.UpdateUser) // محمي بهيدر X-User-ID
	// u: this for users only

	// p:    this is api for posts
	r.POST("api/v0/post/add", AuthMiddleware(), handlerPost.CreatePost)     // محمي بهيدر X-User-ID
	r.POST("api/v0/post/update", AuthMiddleware(), handlerPost.UpdatePost)  // محمي بهيدر X-User-ID
	r.POST("api/v0/post/deleted", AuthMiddleware(), handlerPost.DeletePost) // محمي بهيدر X-User-ID
	r.POST("api/v0/post/get/id", handlerPost.GetPostByID)                   // مفتوح للعامة (يدعم سياق المشاهد الاختياري عبر viewer_id في الـ body)
	// p:    this is api for posts

	// f:    this is api for follow system
	r.POST("api/v0/follow/status", AuthMiddleware(), handlerFollow.CheckFollow)      // محمي بهيدر X-User-ID
	r.POST("api/v0/follow/list", handlerFollow.GetFollowing)                         // مفتوح للعامة
	r.POST("api/v0/follow/discover", AuthMiddleware(), handlerFollow.DiscoverPeople) // محمي بهيدر X-User-ID
	// f:    this is api for follow system

	// c:    this is api for chat and inbox system
	r.POST("api/v0/chat/room/access", AuthMiddleware(), handlerChat.CheckRoomAccess) // محمي بهيدر X-User-ID
	r.POST("api/v0/chat/inbox", AuthMiddleware(), handlerChat.GetUserInbox)          // محمي بهيدر X-User-ID
	// c:    this is api for chat and inbox system

	// m:    this is api for private messages system
	r.POST("api/v0/chat/message/send", AuthMiddleware(), handlerChat.SendMessage)                    // محمي بهيدر X-User-ID
	r.POST("api/v0/chat/message/update", AuthMiddleware(), handlerChat.UpdateMessage)                // محمي بهيدر X-User-ID
	r.POST("api/v0/chat/message/delete", AuthMiddleware(), handlerChat.DeleteMessage)                // محمي بهيدر X-User-ID
	r.POST("api/v0/chat/message/unread-count", AuthMiddleware(), handlerChat.GetUnreadMessagesCount) // محمي بهيدر X-User-ID
	// m:    this is api for private messages system

	// co:   this is api for comments system
	r.POST("api/v0/comments/add", AuthMiddleware(), handlerComment.CreateComment)    // محمي بهيدر X-User-ID
	r.POST("api/v0/comments/get/id", handlerComment.GetCommentByID)                  // مفتوح للعامة
	r.POST("api/v0/comments/list", handlerComment.ListPostComments)                  // مفتوح للعامة
	r.POST("api/v0/comments/search", handlerComment.SearchPostComments)              // مفتوح للعامة
	r.POST("api/v0/comments/update", AuthMiddleware(), handlerComment.UpdateComment) // محمي بهيدر X-User-ID
	r.POST("api/v0/comments/delete", AuthMiddleware(), handlerComment.DeleteComment) // محمي بهيدر X-User-ID
	r.POST("api/v0/comments/batch", handlerComment.BatchGetComments)                 // مفتوح للعامة
	r.POST("api/v0/comments/count", handlerComment.CountComments)                    // مفتوح للعامة
	// co:   this is api for comments system

	// re:   this is api for post reactions system
	r.POST("api/v0/reactions/set", AuthMiddleware(), handlerReaction.SetReaction)             // محمي بهيدر X-User-ID
	r.POST("api/v0/reactions/remove", AuthMiddleware(), handlerReaction.DeleteReaction)       // محمي بهيدر X-User-ID
	r.POST("api/v0/reactions/post-status", handlerReaction.GetPostWithStatus)                 // مفتوح للعامة (سياق مشاهد اختياري عبر viewer_id في الـ body)
	r.POST("api/v0/reactions/feed-batch", AuthMiddleware(), handlerReaction.GetFeedReactions) // محمي بهيدر X-User-ID
	r.POST("api/v0/reactions/users", handlerReaction.GetUsersWhoReacted)                      // مفتوح للعامة
	r.POST("api/v0/reactions/sync-maintenance", handlerReaction.SyncPostMetrics)              // مفتوح للعامة / للصيانة
	// re:   this is api for post reactions system

	return r
}
