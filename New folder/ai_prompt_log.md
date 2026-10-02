# AI Prompt Log – HealthSync

> Nhật ký dưới đây ghi lại các câu hỏi dùng để thảo luận và kiểm tra thiết kế. Có thể chỉnh lại câu chữ để phản ánh đúng các prompt bạn đã thực tế sử dụng.

## Prompt 1 – Lifecycle status

**Prompt:**  
Trong thiết kế cơ sở dữ liệu quan hệ, tại sao dùng một cột `is_active` kiểu BOOLEAN để theo dõi vòng đời của lịch hẹn là một anti-pattern? Khi có 5 trạng thái PENDING, CONFIRMED, CHECKED_IN, COMPLETED và CANCELLED thì nên mô hình hóa bằng cấu trúc nào?

**Kết luận áp dụng:**  
Dùng `ENUM` (hoặc bảng trạng thái riêng nếu hệ thống cần mở rộng mạnh) thay cho Boolean vì Boolean không biểu diễn đủ các bước nghiệp vụ.

## Prompt 2 – Kiểu dữ liệu tiền tệ

**Prompt:**  
Khi thiết kế `deposit_amount` và `penalty_fee` trong MySQL để phục vụ tính toán tài chính, nên dùng FLOAT, DOUBLE hay DECIMAL? Vì sao?

**Kết luận áp dụng:**  
Dùng `DECIMAL(12,2)` vì số thập phân được lưu chính xác theo cơ số 10, tránh sai số biểu diễn nhị phân thường gặp ở FLOAT/DOUBLE.

## Prompt 3 – ALTER TABLE

**Prompt:**  
Cú pháp MySQL để xóa cột `is_active` và thêm cột `status` kiểu ENUM cùng các cột `deposit_amount`, `penalty_fee`, `cancel_reason` vào bảng có sẵn là gì?

**Kết luận áp dụng:**  
Dùng `ALTER TABLE` để thay đổi cấu trúc mà không cần xóa dữ liệu hiện có.

## Prompt 4 – Foreign Key và hành vi xóa

**Prompt:**  
Với quan hệ giữa `Appointments` và `Prescriptions`, nên dùng `ON DELETE CASCADE` hay `ON DELETE RESTRICT` nếu muốn bảo vệ hồ sơ y tế đã phát sinh?

**Kết luận áp dụng:**  
Chọn `ON DELETE RESTRICT` để không cho phép xóa lịch hẹn khi đã có đơn thuốc tham chiếu, tránh mất dữ liệu nghiệp vụ quan trọng.

## Prompt 5 – Trigger bảo vệ nghiệp vụ

**Prompt:**  
Làm thế nào để dùng MySQL Trigger ngăn việc INSERT một đơn thuốc khi lịch hẹn chưa ở trạng thái `COMPLETED`?

**Kết luận áp dụng:**  
Dùng `BEFORE INSERT` (và `BEFORE UPDATE`) để kiểm tra trạng thái lịch hẹn; nếu khác `COMPLETED` thì dùng `SIGNAL SQLSTATE '45000'` để từ chối thao tác.
