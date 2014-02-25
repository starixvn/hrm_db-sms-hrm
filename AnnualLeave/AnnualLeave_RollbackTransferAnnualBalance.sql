USE HRM_SMS
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[AnnualLeave_RollbackTransferAnnualBalance]
	@Year INT,
	@CreatedDate datetime,
	@CreatedBy int,

	@Description NVARCHAR(1000)='',
	@ErrCode int = 0 OUTPUT,
	@ErrMsg varchar(200) = '' OUTPUT	
AS
/*
Created: Tom.Vo@2013.10.29
Task: Transfer annual balance leave.
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
--DECLARE @EmpID INT

--SET @EmpID = 1
IF LEN(ISNULL(@Description,'')) = 0
	SET @Description = 'Rollback Transfer annual balance leave in ' + CONVERT(NVARCHAR(10),@Year) + '.'

DECLARE @DeductDays_local numeric(18,1), @CreditDays_local numeric(18,1)
DECLARE @DeductDays_expat numeric(18,1), @CreditDays_expat numeric(18,1)
DECLARE @FromDate DATETIME,@LoS_Annual DATETIME

SELECT @FromDate = CONVERT(NVARCHAR(10),@YEAR) + '/01/01',
	@LoS_Annual = CONVERT(NVARCHAR(10),@YEAR) + '/01/15'

SELECT @DeductDays_local =0, @CreditDays_local =12
SELECT @DeductDays_expat =0, @CreditDays_expat =42

IF NOT EXISTS(
SELECT TOP 1 1 FROM dbo.LeaveTrans LT WITH(NOLOCK)		
	INNER JOIN   dbo.Employee e WITH(NOLOCK)		ON e.EmpId = LT.EmpId
	INNER JOIN  dbo.EmployeeSummary es WITH(NOLOCK)	On e.EmpId = es.EmpId
WHERE (ISNULL(isdeleted,0)=0 OR (ISNULL(ResignedDate,GETDATE())+3650)< GETDATE() ) AND ISNULL(e.ConfirmedDate,GETDATE() -365) <  @FromDate
		AND LT.FromDate = @FromDate
		AND es.IsLocal = 0 AND LT.[Description] = 'Reset  annual balance leave in ' + CONVERT(NVARCHAR(10),@Year-1)+ '.'
)
BEGIN 
	SELECT @ErrCode = 100 ,@ErrMsg = 'This process has been run last time.'
	RETURN
END

BEGIN TRY
	BEGIN TRANSACTION;
	
		UPDATE es
		SET es.AnnualLeaveBalance = CASE WHEN es.IsLocal = 1 THEN ISNULL(es.AnnualLeaveBalance,0) 
												 - CASE WHEN (DATEDIFF(DD,e.JoinedDate,@LoS_Annual)/(365*5.00))> 1 THEN 
																CASE WHEN DATEPART(DD,e.JoinedDate)<=15 AND DATEPART(MM,e.JoinedDate)=1
																	THEN DATEDIFF(DD,e.JoinedDate,@LoS_Annual)/(365*5)
																	ELSE DATEDIFF(DD,e.JoinedDate,@LoS_Annual)/(365*5) - 1
																END 
															ELSE LT.DeductDays END
											ELSE 0 END
									 -CASE WHEN es.IsLocal = 1 THEN @CreditDays_local ELSE 0 END
									 +CASE WHEN es.IsLocal = 1 THEN @DeductDays_local ELSE 0 END
									
		FROM dbo.EmployeeSummary es  WITH(ROWLOCK,UPDLOCK)
			INNER JOIN dbo.Employee e WITH(NOLOCK) On e.EmpId = es.EmpId
			INNER JOIN dbo.LeaveTrans LT WITH(NOLOCK) On e.EmpId = LT.EmpId
		WHERE (ISNULL(isdeleted,0)=0 OR (ISNULL(ResignedDate,GETDATE())+3650)< GETDATE() ) AND ISNULL(e.ConfirmedDate,GETDATE() -365) <  @FromDate
				AND LT.FromDate = @FromDate
				AND ((es.IsLocal = 0 AND [Description] = 'Reset  annual balance leave in ' + CONVERT(NVARCHAR(10),@Year-1)+ '.' )
						OR es.IsLocal = 1 ) 
				--AND e.EmpId = @EmpID
		DELETE LT
			FROM dbo.LeaveTrans LT
			INNER JOIN  dbo.Employee e WITH(NOLOCK)		ON e.EmpId = LT.EmpId
			INNER JOIN  dbo.EmployeeSummary es WITH(NOLOCK)	On e.EmpId = es.EmpId
		WHERE (ISNULL(isdeleted,0)=0 OR (ISNULL(ResignedDate,GETDATE())+3650)< GETDATE() ) AND ISNULL(e.ConfirmedDate,GETDATE() -365) <  @FromDate
				AND LT.FromDate = @FromDate
				AND [Description] = 'Reset  annual balance leave in ' + CONVERT(NVARCHAR(10),@Year-1)+ '.'
				--AND e.EmpId = @EmpID
		DELETE LT
			FROM dbo.LeaveTrans LT
			INNER JOIN   dbo.Employee e WITH(NOLOCK)		ON e.EmpId = LT.EmpId
			INNER JOIN  dbo.EmployeeSummary es WITH(NOLOCK)	On e.EmpId = es.EmpId
		WHERE (ISNULL(isdeleted,0)=0 OR (ISNULL(ResignedDate,GETDATE())+3650)< GETDATE() ) AND ISNULL(e.ConfirmedDate,GETDATE() -365) <  @FromDate
				AND LT.FromDate = @FromDate
				AND [Description] = 'Transfer annual balance leave in ' + CONVERT(NVARCHAR(10),@Year) + '.'
				--AND e.EmpId = @EmpID
    COMMIT TRANSACTION;
	SELECT @ErrCode=0,@ErrCode=''
END TRY
BEGIN CATCH
			ROLLBACK TRANSACTION;
			SELECT @ErrCode = 100, @ErrMsg = N'Rollback Tranfers anual balance failed.'
			RETURN
END CATCH;

INSERT INTO [dbo].[Log](
		[LogActionID]
		,[LogDate]
		,[Description]
		,[TrackingValue]
		,[UserID]
		)
	SELECT 100, CONVERT(NVARCHAR(10),@YEAR) + '/01/01' as [LogDate],'Rollback Transfer annual balance leave in ' + CONVERT(NVARCHAR(10),@Year) + '.',
	'<LogDate: ' + CONVERT(nvarchar(25),getdate(),101)
	+',DeductDays_local: ' + CONVERT(nvarchar(25),@DeductDays_local)
	+',DeductDays_expat: ' + CONVERT(nvarchar(25),@DeductDays_expat)
	+',CreditDays_local: ' + CONVERT(nvarchar(25),@CreditDays_local)
	+',CreditDays_expat: ' + CONVERT(nvarchar(25),@CreditDays_expat)
	+',ModifiedDate: ' + CONVERT(nvarchar(25),ISNULL(@CreatedDate,getdate()))
	+',ModifiedBy:' + CONVERT(nvarchar(25),ISNULL(@CreatedBy,'-'))
	+'>' as [TrackingValue]
	,1000  AS [UserID]
	 