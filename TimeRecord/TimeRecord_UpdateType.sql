USE [HRM_SMS]
GO
/****** Object:  StoredProcedure [dbo].[Target_Update]    Script Date: 6/19/2014 11:23:42 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[TimeRecord_UpdateType]
	@RecordTimeId INT
	,@InOutType TINYINT
	,@ModifiedBy INT
	,@ModifiedDate DATETIME
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: 20140724@Quinn.Vo
Task: Update Time Record.
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

	DECLARE @EmpId INT, @FromDate DATETIME, @ToDate DATETIME

	SELECT @EmpId = EmpID, @FromDate = RecordTime, @ToDate = RecordTime
	FROM dbo.TimeRecord WITH (NOLOCK)
	WHERE ID = @RecordTimeId

	UPDATE dbo.TimeRecord WITH (ROWLOCK, UPDLOCK)
	SET InOutType = @InOutType,
		ModifiedBy = @ModifiedBy,
		ModifiedDate = @ModifiedDate
	WHERE ID = @RecordTimeId

	EXEC EmployeeAttendance_ProcessingAndInsert @EmpId,  @FromDate, @ToDate, 1

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'Update Time Record failed.'
	END
	ELSE
	BEGIN
		SELECT @ErrCode = 0
			,@ErrMsg = ''
	END
END
