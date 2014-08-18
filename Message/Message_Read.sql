USE [HRM_SMS]
GO

/****** Object:  StoredProcedure [dbo].[Project_Insert]    Script Date: 5/9/2014 10:17:58 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Message_Read] 
	@MessageId INT
	,@EmployeeId INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: 20140728@Quinn.Vo
Task: Update read message.
DB: NexEPA
Original: 

Revisions:  
Param's Explanation:
• @ErrCode:
	= 0: Transaction recorded successfully.
	> 0: Specific Error.
• @ErrMsg: Error description.

*/
BEGIN
	SET NOCOUNT ON;

	IF(EXISTS(SELECT 1 FROM dbo.MessageEmployee WITH (NOLOCK) WHERE MessageId = @MessageId AND EmployeeId = @EmployeeId))
	BEGIN
		UPDATE dbo.MessageEmployee WITH (ROWLOCK, UPDLOCK)
		SET IsRead = 1
		WHERE MessageId = @MessageId
		AND EmployeeId = @EmployeeId
	END
	ELSE
	BEGIN
		INSERT INTO dbo.MessageEmployee(MessageId, EmployeeId, Email, IsDisabled, IsRead)
		SELECT @MessageId, @EmployeeId, Email, 0, 1
		FROM dbo.Employee WITH (NOLOCK)
		WHERE EmpId = @EmployeeId
	END

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'Update read message failed.'
	END
	ELSE
	BEGIN
		SELECT @ErrCode = 0
			,@ErrMsg = ''
	END
END
