
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_GetRangeDateByRequestID]    Script Date: 2013-11-22 11:59:35 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[WorkingTimeRequest_AvaibleBalanceLeave]
	@EmpId int,
	@RequestID BigInt=NULL,
	@EffectedDay DATETIME=NULL
AS
/*
Created: Tom.Vo@2013-11-05
Task: Get  Avaible Balance Leave From Request ID
DB: HRM_SMS
Original: 

Revisions:
Param's Explanation:

*/
SET NOCOUNT ON;

IF @EffectedDay	IS NULL
	SELECT @EffectedDay = CONVERT(DATETIME,CONVERT(NVARCHAR(10),YEAR(GETDATE())) +  '/01/01')

DECLARE @KIVBalance numeric(18,2)
DECLARE  @LeaveBalanceDay numeric(18,2),@CreditDays numeric(18,2),@DeductDays numeric(18,2)
DECLARE @LeaveDays numeric(18,2),@CurrenLeaveDays numeric(18,2)	

SELECT TOP 1 @LeaveDays=SUM(tmp.TOTALDAYS),
			@CurrenLeaveDays=SUM(CASE WHEN MONTH(lr.ToDate)>MONTH(GETDATE()) THEN 0 ELSE tmp.TOTALDAYS END)
FROM dbo.tmpLeaveBalance tmp WITH(NOLOCK) 
	LEFT JOIN dbo.LeaveRequest lr WITH(NOLOCK) 
		ON tmp.EmpId = lr.EmpId AND tmp.RequestID = lr.RequestId
WHERE tmp.EmpId = @EmpId AND Status = 0 AND tmp.InYear=YEAR(GETDATE())

SELECT TOP 1 @KIVBalance=SUM(TOTALDAYS)			
FROM dbo.tmpKIVLeaveBalance WITH(NOLOCK) 
WHERE EmpId = @EmpId AND Status = 0 AND InYear=YEAR(GETDATE())

IF @RequestID IS NOT NULL
BEGIN
	SELECT TOP 1 @LeaveDays=ISNULL(@LeaveDays,0) - SUM(TOTALDAYS) FROM dbo.tmpLeaveBalance WITH(NOLOCK) WHERE EmpId = @EmpId AND @RequestID = RequestID AND [Status] <> 2
	SELECT TOP 1 @KIVBalance=ISNULL(@KIVBalance,0) - SUM(TOTALDAYS) FROM dbo.tmpKIVLeaveBalance WITH(NOLOCK) WHERE EmpId = @EmpId AND @RequestID = RequestID AND [Status] <> 2
END

SELECT TOP 1 @KIVBalance=KeepInViewBalance-ISNULL(@KIVBalance,0)   
FROM dbo.EmployeeSummary WITH(NOLOCK) WHERE EmpId = @EmpId 

SELECT @CreditDays = SUM(CASE WHEN FromDate <= @EffectedDay THEN ISNULL(CreditDays,0) ELSE 0 END),
		@LeaveBalanceDay=SUM(ISNULL(CreditDays,0)),
		@DeductDays = SUM(ISNULL(DeductDays,0)),
		@CurrenLeaveDays=ISNULL(@CurrenLeaveDays,0)+SUM(CASE WHEN MONTH(FromDate)>MONTH(GETDATE()) THEN 0 ELSE ISNULL(DeductDays,0) END)
From dbo.LeaveTrans WITH(NOLOCK) Where EmpID= @EmpID 
	AND YEAR(FromDate) = YEAR(@EffectedDay) 
	AND ISNULL(Deleted,0)<>1

SELECT @LeaveBalanceDay=ISNULL(@LeaveBalanceDay,0)-ISNULL(@DeductDays,0)-ISNULL(@LeaveDays,0)		

IF EXISTS(SELECT TOP 1 1 FROM dbo.EmployeeSummary WITH(NOLOCK) WHERE EmpId=@EmpId AND IsLocal = 1 )
	BEGIN
		SELECT @CurrenLeaveDays = MONTH(GETDATE())+5-ISNULL(@CurrenLeaveDays,0)
	END
ELSE
	SELECT @CurrenLeaveDays=ISNULL(@CreditDays,0)- ISNULL(@CurrenLeaveDays,0)

SELECT @EmpId AS EmployeeId,ISNULL(@LeaveBalanceDay,0) AnnualBalance,
	ISNULL(@KIVBalance,0) KeepInViewBalance,
	CASE WHEN ISNULL(@LeaveBalanceDay,0) < ISNULL(@CurrenLeaveDays,0) THEN ISNULL(@LeaveBalanceDay,0)
	ELSE ISNULL(@CurrenLeaveDays,0) END CurrentLeaveBalanceDay