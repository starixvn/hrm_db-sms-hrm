USE [HRM_SMS]
GO
/****** Object:  StoredProcedure [dbo].[Employee_ChangePassword]    Script Date: 2013-10-29 4:18:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].Employee_UpdatePasswordResetStatusByEmpId 
	@empId int,
	@PasswordReset BIT=0,

	@ErrCode int = 0 OUTPUT,
	@ErrMsg varchar(200) = '' OUTPUT
AS
/*
Created: Tom.Vo@2013-10-23 
Task: Update passowrd Employee
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	UPDATE Employee WITH (UPDLOCK,ROWLOCK)
	SET PasswordReset=@PasswordReset
	WHERE empId = @empId

	IF @@ERROR <> 0
		SELECT @ErrCode = 102, @ErrMsg = N'Update Password Reset Employee failed.'
	ELSE 
		SELECT @ErrCode=0,@ErrCode=''	
END