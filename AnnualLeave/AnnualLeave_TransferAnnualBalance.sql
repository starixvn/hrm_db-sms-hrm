USE HRM_SMS
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[AnnualLeave_TransferAnnualBalance]
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

IF LEN(ISNULL(@Description,'')) = 0
	SET @Description = 'Transfer annual balance leave in ' + CONVERT(NVARCHAR(10),@Year) + '.'

DECLARE @DeductDays_local numeric(18,1), @CreditDays_local numeric(18,1)
DECLARE @DeductDays_expat numeric(18,1), @CreditDays_expat numeric(18,1)
DECLARE @FromDate DATETIME,@LoS_Annual DATETIME
DECLARE @MaxTranferAnnualLeaveBalance numeric(18,1)
SELECT @FromDate = CONVERT(NVARCHAR(10),@YEAR) + '/01/01',
	@LoS_Annual = CONVERT(NVARCHAR(10),@YEAR) + '/01/15'

SELECT @DeductDays_local =0, @CreditDays_local =12
SELECT @DeductDays_expat =0, @CreditDays_expat =42
SELECT @MaxTranferAnnualLeaveBalance =3
--DECLARE @EmpID INT = 1

IF EXISTS(
SELECT TOP 1 1 FROM dbo.LeaveTrans LT WITH(NOLOCK)		
	INNER JOIN   dbo.Employee e WITH(NOLOCK)		ON e.EmpId = LT.EmpId
	INNER JOIN  dbo.EmployeeSummary es WITH(NOLOCK)	On e.EmpId = es.EmpId
WHERE (ISNULL(isdeleted,0)=0 OR (ISNULL(ResignedDate,GETDATE())+3650)< GETDATE() ) AND ISNULL(e.ConfirmedDate,GETDATE() -365) <  @FromDate
		AND LT.FromDate = @FromDate
		AND es.IsLocal = 0 AND [Description] = 'Reset  annual balance leave in ' + CONVERT(NVARCHAR(10),@Year-1)
)
BEGIN 
	SELECT @ErrCode = 100 ,@ErrMsg = 'This process has been run last time.'
	RETURN
END


BEGIN TRY
	BEGIN TRANSACTION;

		INSERT INTO dbo.LeaveTrans(EmpId, [Description], FromDate, DeductDays,CreditDays, CreatedDate, CreatedBy)	
		SELECT e.EmpId,  'Reset  annual balance leave in ' + CONVERT(NVARCHAR(10),@Year-1) + '.' [Description], DATEADD(DD,-1,@FromDate) FromDate, 
			es.AnnualLeaveBalance DeductDays,
			0 CreditDays, 
			@CreatedDate, @CreatedBy
		from dbo.Employee e WITH(NOLOCK)
			INNER JOIN  dbo.EmployeeSummary es WITH(NOLOCK)
				On e.EmpId = es.EmpId
			INNER JOIN dbo.LeaveTrans lt 
				On lt.EmpId = es.EmpId AND YEAR(lt.FromDate) = YEAR(DATEADD(DD,-1,@FromDate)) AND lt.CreditDays >=0
		WHERE (ISNULL(isdeleted,0)=0 OR (ISNULL(ResignedDate,GETDATE())+3650)< GETDATE() ) AND ISNULL(e.ConfirmedDate,GETDATE() -365) <  @FromDate
				AND e.EmpId not in (16,139)
				
		INSERT INTO dbo.LeaveTrans(EmpId, [Description], FromDate, DeductDays,CreditDays, CreatedDate, CreatedBy)	
		SELECT e.EmpId,  @Description, @FromDate, 
			CASE WHEN es.IsLocal = 1 THEN @DeductDays_local ELSE @DeductDays_local END DeductDays,
			CASE WHEN es.IsLocal = 1 THEN  CASE WHEN ISNULL(es.AnnualLeaveBalance,0) > @MaxTranferAnnualLeaveBalance THEN 
												@MaxTranferAnnualLeaveBalance ELSE ISNULL(es.AnnualLeaveBalance,0)  END  + @CreditDays_local
									 + CASE WHEN (DATEDIFF(DD,e.JoinedDate,@LoS_Annual)/(365*5.00))> 1 THEN 
													CASE WHEN DATEPART(DD,e.JoinedDate)<=15 AND DATEPART(MM,e.JoinedDate)=1
														THEN DATEDIFF(DD,e.JoinedDate,@LoS_Annual)/(365*5)
														ELSE DATEDIFF(DD,e.JoinedDate,@LoS_Annual)/(365*5) - 1
													END 
												ELSE 0 END
				 ELSE @CreditDays_expat END CreditDays, 
			@CreatedDate, @CreatedBy
		from dbo.Employee e WITH(NOLOCK)
			INNER JOIN  dbo.EmployeeSummary es WITH(NOLOCK)
				On e.EmpId = es.EmpId
		WHERE (ISNULL(isdeleted,0)=0 OR (ISNULL(ResignedDate,GETDATE())+3650)< GETDATE() ) AND ISNULL(e.ConfirmedDate,GETDATE() -365) <  @FromDate
		AND e.EmpId not in (16,139)
		
		UPDATE es
		SET es.AnnualLeaveBalance = CASE WHEN es.IsLocal = 1 THEN 
									  CASE WHEN ISNULL(es.AnnualLeaveBalance,0) > @MaxTranferAnnualLeaveBalance THEN 
												@MaxTranferAnnualLeaveBalance ELSE ISNULL(es.AnnualLeaveBalance,0)  END
									 + CASE WHEN (DATEDIFF(DD,e.JoinedDate,@LoS_Annual)/(365*5.00))> 1 THEN 
													CASE WHEN DATEPART(DD,e.JoinedDate)<=15 AND DATEPART(MM,e.JoinedDate)=1
														THEN DATEDIFF(DD,e.JoinedDate,@LoS_Annual)/(365*5)
														ELSE DATEDIFF(DD,e.JoinedDate,@LoS_Annual)/(365*5) - 1
													END 
												ELSE 0 END
											ELSE 0 END
									 +CASE WHEN es.IsLocal = 1 THEN @CreditDays_local ELSE @CreditDays_expat END
									 -CASE WHEN es.IsLocal = 1 THEN @DeductDays_local ELSE @DeductDays_expat END
									
		FROM dbo.EmployeeSummary es  WITH(ROWLOCK,UPDLOCK)
			INNER JOIN dbo.Employee e WITH(NOLOCK)
				On e.EmpId = es.EmpId
		WHERE (ISNULL(isdeleted,0)=0 OR (ISNULL(ResignedDate,GETDATE())+3650)< GETDATE() ) AND ISNULL(e.ConfirmedDate,GETDATE() -365) <  @FromDate
		AND e.EmpId not in (16,139)
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
	SELECT 100, CONVERT(NVARCHAR(10),@YEAR) + '/01/01' as [LogDate],'Transfer annual balance leave in ' + CONVERT(NVARCHAR(10),@Year) + '.',
	'<LogDate: ' + CONVERT(nvarchar(25),getdate(),101)
	+',DeductDays_local: ' + CONVERT(nvarchar(25),@DeductDays_local)
	+',DeductDays_expat: ' + CONVERT(nvarchar(25),@DeductDays_expat)
	+',CreditDays_local: ' + CONVERT(nvarchar(25),@CreditDays_local)
	+',CreditDays_expat: ' + CONVERT(nvarchar(25),@CreditDays_expat)
	+',ModifiedDate: ' + CONVERT(nvarchar(25),ISNULL(@CreatedDate,getdate()))
	+',ModifiedBy:' + CONVERT(nvarchar(25),ISNULL(@CreatedBy,'-'))
	+'>' as [TrackingValue]
	,1000  AS [UserID]
	 