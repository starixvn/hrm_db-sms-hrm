
USE HRM_SMS
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[DBA_AnnualLeave_DeleteAnnualBalance]
	@Year INT,
	@EmpID INT=NULL,
	@CreatedDate datetime,
	@CreatedBy int,

	@Description NVARCHAR(1000)='',
	@ErrCode int = 0 OUTPUT,
	@ErrMsg varchar(200) = '' OUTPUT	
AS
/*
Created: Tom.Vo@2013.10.29
Task: create annual balance leave.
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF LEN(ISNULL(@Description,'')) = 0
	SET @Description = 'Delete annual balance leave in ' + CONVERT(NVARCHAR(10),@Year) + '.'

DECLARE @FromDate DATETIME,@ToDate DATETIME,@LoS_Annual DATETIME

SELECT @FromDate = CONVERT(NVARCHAR(10),@YEAR) + '/01/01',
	@LoS_Annual = CONVERT(NVARCHAR(10),@YEAR) + '/01/15'

SELECT @ToDate = DATEADD(DD,-1,DATEADD(YY,1,@FromDate))

BEGIN TRY
	BEGIN TRANSACTION;

		UPDATE ES 
		SET AnnualLeaveBalance = es.AnnualLeaveBalance - lt.CreditDays
		FROM dbo.EmployeeSummary ES 
		INNER JOIN LeaveTrans lt 
			ON ES.EmpId =  lt.EmpId AND FromDate= @FromDate AND ISNULL(lt.Deleted,0) = 0
		WHERE ES.EmpId = @EmpID OR @EmpID IS NULL
		
		DELETE dbo.LeaveTrans
		WHERE (EmpId = @EmpID OR @EmpID IS NULL) AND FromDate= @FromDate AND CreditDays > 0		
		
    COMMIT TRANSACTION;
	SELECT @ErrCode=0,@ErrCode=''
END TRY
BEGIN CATCH
			ROLLBACK TRANSACTION;
			SELECT @ErrCode = 100, @ErrMsg = N'Tranfers anual balance failed.'
			RETURN
END CATCH;

INSERT INTO [dbo].[Log](
		[LogActionID]
		,[LogDate]
		,[Description]
		,[TrackingValue]
		,[UserID]
		)
	SELECT 100, CONVERT(NVARCHAR(10),@YEAR) + '/01/01' as [LogDate],'Delete annual balance leave in ' + CONVERT(NVARCHAR(10),@Year) + '.',
	'<LogDate: ' + CONVERT(nvarchar(25),getdate(),101)
	+',ModifiedDate: ' + CONVERT(nvarchar(25),ISNULL(@CreatedDate,getdate()))
	+',ModifiedBy:' + CONVERT(nvarchar(25),ISNULL(@CreatedBy,'-'))
	+'>' as [TrackingValue]
	,1000  AS [UserID]
	 