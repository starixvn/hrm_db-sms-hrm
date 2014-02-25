USE HRM_SMS
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].WorkingTimeRequest_Delete_TmpLeaveBalance
	@Requestid bigint,
	@EmpID INT,
	@Status INT=1
	
AS
/*
Created: Tom.Vo@2013-11-05
Task: Delete_TmpLeaveBalance
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
	
*/
SET NOCOUNT ON;


UPDATE dbo.tmpLeaveBalance WITH(ROWLOCK,UPDLOCK)
SET [Status] = @Status 
WHERE Requestid = @Requestid
