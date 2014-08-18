USE [HRM_SMS]
GO

/****** Object:  StoredProcedure [dbo].[Project_Insert]    Script Date: 5/9/2014 10:17:58 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Message_Update] 
	@MessageId INT
	,@Subject VARCHAR(100)
	,@Contents NVARCHAR(MAX)
	,@Category TINYINT
	,@FromDate DATETIME = NULL
	,@ToDate DATETIME = NULL
	,@EmployeeIds VARCHAR(500) = ''
	,@GroupIds VARCHAR(500) = ''
	,@ModifiedBy INT
	,@ModifiedDate DATETIME
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: 20140714@Quinn.Vo
Task: Update Message.
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

	IF(@FromDate IS NOT NULL AND @ToDate IS NOT NULL AND @FromDate > @ToDate)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'.The From Date must be less than To Date.'

		RETURN
	END

	DECLARE @Employees TABLE(
		EmployeeId INT
	)
	DECLARE @Groups TABLE(
		GroupId INT
	)

	UPDATE dbo.[Message] WITH (ROWLOCK, UPDLOCK)
	SET [Subject] = @Subject,
		Contents = @Contents,
		Category = @Category,
		FromDate = @FromDate,
		ToDate = @ToDate,
		ModifiedBy = @ModifiedBy,
		ModifiedDate = @ModifiedDate
	WHERE MessageId = @MessageId

	DELETE FROM dbo.MessageGroup WHERE MessageId = @MessageId
	IF(@GroupIds <> '')
	BEGIN
		INSERT INTO @Groups (GroupId)
		SELECT val FROM fnc_strSplit (@GroupIds, ',')

		INSERT INTO dbo.MessageGroup(MessageId, GroupId, Email)
		SELECT @MessageId, g.GroupId, gr.MailGroup
		FROM @Groups AS g INNER JOIN
		dbo.[Group] AS gr ON g.GroupId = gr.GroupId
	END

	DELETE FROM dbo.MessageEmployee WHERE MessageId = @MessageId
	IF(@EmployeeIds <> '')
	BEGIN
		INSERT INTO @Employees (EmployeeId)
		SELECT val FROM fnc_strSplit (@EmployeeIds, ',')

		INSERT INTO dbo.MessageEmployee(MessageId, EmployeeId, Email, IsDisabled, IsRead)
		SELECT @MessageId, e.EmployeeId, ee.Email, 0, 0
		FROM @Employees AS e INNER JOIN
		dbo.Employee AS ee ON e.EmployeeId = ee.EmpId
	END

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'Update Message failed.'
	END
	ELSE
	BEGIN
		SELECT @ErrCode = 0
			,@ErrMsg = ''
	END
END
