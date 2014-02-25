USE [HRM_SMS]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[EmployeeSupervisor_InsertEmpMngShiftList]
	@EmpId  INT,
	--@Role	TINYINT=4,
	@EmpIdShift VARCHAR(5000) = '',
	@ModifiedBy INT,
	
	@ErrCode int = 0 OUTPUT,
	@ErrMsg varchar(200) = '' OUTPUT	
AS
/*
Created: @Tom.Vo@2013-10-30
Task: Insert list employee by  Shift role
DB: HRM_SMS
Original:

Revisions:
Param's Explanation:
*/
SET NOCOUNT ON 
DECLARE @Role	TINYINT
SET @Role =4

CREATE TABLE #SupervisorId (OwnerId INT,RequestType	TINYINT,OrderNo SmallINT IDENTITY(1, 1))

IF ISNULL(@EmpIdShift,'') <> ''
	INSERT INTO #SupervisorId (OwnerId,RequestType)
	SELECT val,RequestType FROM fnc_strSplit (@EmpIdShift, ',')  , (SELECT 0 as RequestType) tblRole

DELETE FROM [dbo].[EmployeeSupervisor] 
WHERE EmpId = @EmpId AND ActionType = @Role

INSERT INTO [dbo].[EmployeeSupervisor] (
	EmpId, 
	OwnerId, 
	ActionType, 
	RequestType, 
	ModifiedBy, 
	ModifiedDate,
	OrderNo)
SELECT @EmpId EmpId, OwnerId, @Role, RequestType, @ModifiedBy, GETDATE(),OrderNo
FROM #SupervisorId

 IF @@ERROR <> 0 
	SELECT @ErrCode=100,@ErrMsg=N'Insert list employee by  Shift role failed'
ELSE 
	SELECT @ErrCode=0,@ErrMsg=''

DROP TABLE #SupervisorId