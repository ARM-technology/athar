# استخدام نسخة Go الرسمية والخفيفة
FROM golang:1.26-alpine

# تحديد مجلد العمل داخل الحاوية
WORKDIR /app

# نسخ ملفات التعريف وتحميل الاعتمادات
COPY go.mod ./
RUN go mod download

# نسخ باقي ملفات المشروع
COPY . .

# بناء التطبيق
RUN go build -o main .

# أمر تشغيل التطبيق عند تشغيل الحاوية
CMD ["./main"]