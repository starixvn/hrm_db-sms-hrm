USE HRM_SMS
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[DBA_AnnualLeave_TranferAnnualBalance]
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

IF YEAR(GETDATE())<=@YEAR
BEGIN
			SELECT @ErrCode = 100, @ErrMsg = N'Current Year could not tranfer annual. Tranfers annual balance failed.'
			RETURN
END

IF LEN(ISNULL(@Description,'')) = 0
	SET @Description = 'Tranfer annual balance leave in ' + CONVERT(NVARCHAR(10),@Year) + '.'

DECLARE @FromDate DATETIME,@ToDate DATETIME

SELECT @FromDate = CONVERT(NVARCHAR(10),@YEAR) + '/12/31'

SELECT @ToDate = @FromDate

BEGIN TRY
	BEGIN TRANSACTION;

		UPDATE ES 
		SET AnnualLeaveBalance = es.AnnualLeaveBalance - lt.DeductDays
		FROM dbo.EmployeeSummary ES 
		INNER JOIN (SELECT SUM(CreditDays-DeductDays) DeductDays,EmpId 
						FROM dbo.LeaveTrans lt 
						WHERE YEAR(lt.FromDate) = @Year AND ISNULL(Deleted,0) = 0
						GROUP BY EmpId 
						) lt
			ON ES.EmpId =  lt.EmpId
		WHERE ES.EmpId = @EmpID OR @EmpID IS NULL
		
		INSERT INTO dbo.LeaveTrans(EmpId, [Description], FromDate,ToDate, DeductDays,CreditDays, CreatedDate, CreatedBy,Deleted)	
		SELECT e.EmpId,  @Description Description, @FromDate FromDate, @ToDate ToDate,
			lt.DeductDays DeductDays,0 CreditDays, 
			@CreatedDate CreatedDate, @CreatedBy CreatedBy,0 Deleted 
		from dbo.Employee e WITH(NOLOCK)
			INNER JOIN  dbo.EmployeeSummary es WITH(NOLOCK)
				On e.EmpId = es.EmpId
			INNER JOIN (SELECT SUM(CreditDays-DeductDays) DeductDays,EmpId 
						FROM dbo.LeaveTrans lt 
						WHERE YEAR(lt.FromDate) = @Year AND ISNULL(Deleted,0) = 0
						GROUP BY EmpId 
						) lt
				ON e.EmpId = lt.EmpId 
		WHERE (ISNULL(isdeleted,0)=0 OR (ISNULL(ResignedDate,GETDATE())+3650)< GETDATE() ) AND ISNULL(e.ConfirmedDate,GETDATE() -365) <  @FromDate
		AND (e.EmpId = @EmpID OR @EmpID IS NULL)
		
    COMMIT TRANSACTION;
	SELECT @ErrCode=0,@ErrCode=''
END TRY
BEGIN CATCH
			ROLLBACK TRANSACTION;
			SELECT @ErrCode = 100, @ErrMsg = N'Tranfers annual balance failed.'
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
	 