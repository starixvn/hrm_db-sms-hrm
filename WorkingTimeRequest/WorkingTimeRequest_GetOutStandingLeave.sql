USE [HRM_SMS]
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_GetRangeDateByRequestID]    Script Date: 2013-11-22 11:59:35 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[WorkingTimeRequest_GetOutStandingLeave]
	@EmpId int,
	@RequestID BigInt=NULL
AS
/*
Created: Tom.Vo@2013-11-05
Task: Get  OutStanding Leave From Request ID
DB: HRM_SMS
Original: 

Revisions:
Param's Explanation:

*/
SET NOCOUNT ON;
DECLARE @AnnualLeaveBalance numeric(18,2), @KIVBalance numeric(18,2)

SELECT TOP 1 @AnnualLeaveBalance=SUM(TOTALDAYS) FROM dbo.tmpLeaveBalance WITH(NOLOCK) WHERE EmpId = @EmpId AND Status = 0
SELECT TOP 1 @KIVBalance=SUM(TOTALDAYS)			FROM dbo.tmpKIVLeaveBalance WITH(NOLOCK) WHERE EmpId = @EmpId AND Status = 0

IF @RequestID IS NOT NULL
BEGIN
	SELECT TOP 1 @AnnualLeaveBalance=ISNULL(@AnnualLeaveBalance,0) - SUM(TOTALDAYS) FROM dbo.tmpLeaveBalance WITH(NOLOCK) WHERE EmpId = @EmpId AND @RequestID = RequestID
	SELECT TOP 1 @KIVBalance=ISNULL(@KIVBalance,0) - SUM(TOTALDAYS)					FROM dbo.tmpKIVLeaveBalance WITH(NOLOCK) WHERE EmpId = @EmpId AND @RequestID = RequestID
END

SELECT @EmpId AS EmployeeId,ISNULL(@AnnualLeaveBalance,0) AnnualBalance,ISNULL(@KIVBalance,0) KeepInViewBalance