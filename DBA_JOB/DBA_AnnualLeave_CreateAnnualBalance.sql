USE HRM_SMS
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[DBA_AnnualLeave_CreateAnnualBalance]
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
Task: DELETE annual balance leave.
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF LEN(ISNULL(@Description,'')) = 0
	SET @Description = 'Create annual balance leave in ' + CONVERT(NVARCHAR(10),@Year) + '.'

DECLARE @DeductDays_local numeric(18,1), @CreditDays_local numeric(18,1)
DECLARE @DeductDays_expat numeric(18,1), @CreditDays_expat numeric(18,1)
DECLARE @FromDate DATETIME,@ToDate DATETIME,@LoS_Annual DATETIME
DECLARE @MaxTranferAnnualLeaveBalance numeric(18,1)
SELECT @FromDate = CONVERT(NVARCHAR(10),@YEAR) + '/01/01',
	@LoS_Annual = CONVERT(NVARCHAR(10),@YEAR) + '/01/07'

SELECT @ToDate = DATEADD(DD,-1,DATEADD(YY,1,@FromDate))

SELECT @DeductDays_local =0, @CreditDays_local =12
SELECT @DeductDays_expat =0, @CreditDays_expat =42
SELECT @MaxTranferAnnualLeaveBalance =0

BEGIN TRY
	BEGIN TRANSACTION;
		INSERT INTO dbo.LeaveTrans(EmpId, [Description], FromDate,ToDate, DeductDays,CreditDays, CreatedDate, CreatedBy,Deleted)	
		SELECT e.EmpId,  @Description Description, @FromDate FromDate, @ToDate ToDate,
			CASE WHEN es.IsLocal = 1 THEN @DeductDays_local ELSE @DeductDays_local END DeductDays,
			CASE WHEN es.IsLocal = 1 THEN  CASE WHEN ISNULL(es.AnnualLeaveBalance,0) > @MaxTranferAnnualLeaveBalance THEN 
												@MaxTranferAnnualLeaveBalance ELSE ISNULL(es.AnnualLeaveBalance,0)  END  + @CreditDays_local
									 + CASE WHEN (DATEDIFF(DD,e.JoinedDate,@LoS_Annual)/(365*5.00))> 1 THEN 
													--CASE WHEN DATEPART(DD,e.JoinedDate)<=15 AND DATEPART(MM,e.JoinedDate)=1
													--	THEN 
														DATEDIFF(DD,e.JoinedDate,@LoS_Annual)/(365*5)
													--	ELSE DATEDIFF(DD,e.JoinedDate,@LoS_Annual)/(365*5) - 1
													--END 
												ELSE 0 END
				 ELSE @CreditDays_expat END CreditDays, 
			@CreatedDate CreatedDate, @CreatedBy CreatedBy,0 Deleted 
		from dbo.Employee e WITH(NOLOCK)
			INNER JOIN  dbo.EmployeeSummary es WITH(NOLOCK)
				On e.EmpId = es.EmpId
			LEFT JOIN (SELECT MAX(FromDate) FromDate,EmpId 
						FROM dbo.LeaveTrans lt 
						WHERE lt.FromDate >=@FromDate AND lt.CreditDays >0 AND ISNULL(Deleted,0) = 0
						GROUP BY EmpId 
						) lt				
				ON e.EmpId = lt.EmpId 
		WHERE (ISNULL(isdeleted,0)=0 OR (ISNULL(ResignedDate,GETDATE())+3650)< GETDATE() ) AND ISNULL(e.ConfirmedDate,GETDATE() -365) <  @FromDate
		AND (e.EmpId = @EmpID OR @EmpID IS NULL)
		AND lt.EmpId IS NULL
		
		UPDATE es
		SET es.AnnualLeaveBalance = es.AnnualLeaveBalance
										 + CASE WHEN (DATEDIFF(DD,e.JoinedDate,@LoS_Annual)/(365*5.00))> 1 THEN 
														CASE WHEN DATEPART(DD,e.JoinedDate)<=15 AND DATEPART(MM,e.JoinedDate)=1
															THEN DATEDIFF(DD,e.JoinedDate,@LoS_Annual)/(365*5)
															ELSE DATEDIFF(DD,e.JoinedDate,@LoS_Annual)/(365*5) - 1
														END 
													ELSE 0 END
									 +CASE WHEN es.IsLocal = 1 THEN @CreditDays_local ELSE @CreditDays_expat END
									 -CASE WHEN es.IsLocal = 1 THEN @DeductDays_local ELSE @DeductDays_expat END
									
		FROM dbo.EmployeeSummary es  WITH(ROWLOCK,UPDLOCK)
			INNER JOIN dbo.Employee e WITH(NOLOCK)
				On e.EmpId = es.EmpId
			INNER JOIN (SELECT MAX(FromDate) FromDate,EmpId 
						FROM dbo.LeaveTrans lt 
						WHERE lt.FromDate >=@FromDate AND lt.CreditDays >0 AND ISNULL(Deleted,0) = 0
						GROUP BY EmpId 
						) lt				
				ON e.EmpId = lt.EmpId
		WHERE (ISNULL(isdeleted,0)=0 OR (ISNULL(ResignedDate,GETDATE())+3650)< GETDATE() ) AND ISNULL(e.ConfirmedDate,GETDATE() -365) <  @FromDate
		AND es.AnnualLeaveBalance < CASE WHEN es.IsLocal = 1 THEN 12 ELSE 42 END
		AND e.EmpId = @EmpID OR @EmpID IS NULL		

    COMMIT TRANSACTION;
	SELECT @ErrCode=0,@ErrCode=''
END TRY
BEGIN CATCH
			ROLLBACK TRANSACTION;
			SELECT @ErrCode = 100, @ErrMsg = N'Create anual balance failed.'
			RETURN
END CATCH;

INSERT INTO [dbo].[Log](
		[LogActionID]
		,[LogDate]
		,[Description]
		,[TrackingValue]
		,[UserID]
		)
	SELECT 100, CONVERT(NVARCHAR(10),@YEAR) + '/01/01' as [LogDate],'Create annual balance leave in ' + CONVERT(NVARCHAR(10),@Year) + '.',
	'<LogDate: ' + CONVERT(nvarchar(25),getdate(),101)
	+',DeductDays_local: ' + CONVERT(nvarchar(25),@DeductDays_local)
	+',DeductDays_expat: ' + CONVERT(nvarchar(25),@DeductDays_expat)
	+',CreditDays_local: ' + CONVERT(nvarchar(25),@CreditDays_local)
	+',CreditDays_expat: ' + CONVERT(nvarchar(25),@CreditDays_expat)
	+',ModifiedDate: ' + CONVERT(nvarchar(25),ISNULL(@CreatedDate,getdate()))
	+',ModifiedBy:' + CONVERT(nvarchar(25),ISNULL(@CreatedBy,'-'))
	+'>' as [TrackingValue]
	,1000  AS [UserID]