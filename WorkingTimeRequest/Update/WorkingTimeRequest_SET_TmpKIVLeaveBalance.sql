USE HRM_SMS
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].WorkingTimeRequest_SET_TmpKIVLeaveBalance
	@Requestid bigint,
	@EmpID INT,
	@TotalDays Decimal(18,2) 
AS
/*
Created: Tom.Vo@2013-11-05
Task: [tmpKIVLeaveBalance]
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
	
*/
SET NOCOUNT ON;

IF EXISTS(SELECT TOP 1 1 FROM dbo.[tmpKIVLeaveBalance] WITH(NOLOCK) WHERE  EmpID = @EmpID AND Requestid = @Requestid)
	DELETE FROM dbo.[tmpKIVLeaveBalance] WHERE  EmpID = @EmpID AND Requestid = @Requestid

INSERT INTO dbo.[tmpKIVLeaveBalance] (EmpID,Requestid,TotalDays,InYear,[Status] )
SELECT TOP 1 @EmpID,@Requestid,@TotalDays,YEAR(TODATE),0 
FROM dbo.LeaveRequest lr WITH(NOLOCK)
WHERE Requestid = @Requestid
