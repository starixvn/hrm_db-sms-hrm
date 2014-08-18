USE [HRM_SMS]
GO

/****** Object:  StoredProcedure [dbo].[Project_Insert]    Script Date: 5/9/2014 10:17:58 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Message_Delete] 
	@MessageId INT
	,@ModifiedBy INT
	,@ModifiedDate DATETIME
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: 20140714@Quinn.Vo
Task: Delete Message.
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

	UPDATE dbo.[Message] WITH (ROWLOCK, UPDLOCK)
	SET IsDisabled = 1,
		ModifiedBy = @ModifiedBy,
		ModifiedDate = @ModifiedDate
	WHERE MessageId = @MessageId

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'Delete Message failed.'
	END
	ELSE
	BEGIN
		SELECT @ErrCode = 0
			,@ErrMsg = ''
	END
END
