--USE [HRM_SMS]
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

SELECT * INTO #tmpEmployeeSupervisor 
FROM EmployeeSupervisor WITH(NOLOCK)
WHERE EmpId = @EmpId AND ActionType = @Role

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
	BEGIN
		
		DELETE FROM [dbo].[EmployeeSupervisor] 
		WHERE EmpId = @EmpId AND ActionType = @Role

		INSERT INTO [dbo].[EmployeeSupervisor]
		SELECT * FROM #tmpEmployeeSupervisor

		SELECT @ErrCode=100,@ErrMsg=N'Insert list employee by  Shift role failed'
	END
ELSE 
	SELECT @ErrCode=0,@ErrMsg=''

DROP TABLE #SupervisorId
DROP TABLE #tmpEmployeeSupervisor

Declare @LogSPData varchar(4000), @now datetime
	set @now=getdate()
	--Log general info
	Select @LogSPData = '<EmployeeSupervisor_InsertEmpMngShiftList ActionType="'+ coalesce(cast(@Role as varchar(50)),space(1)) + '" ' +
	'EmpId="'+ coalesce(cast(@EmpId as varchar(100)),space(1)) + '" ' +
	'Owner="'+ coalesce(cast(@EmpIdShift as varchar(4000)),space(1)) + '" ' +	
	'ErrCode="'+ coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" ' +
	'ErrMsg="'+ coalesce(cast(@ErrMsg as varchar(4000)),space(1)) + '" />'	

	EXEC dbo.Log_WriteLog
		@LogActionID = 1001,
		@LogDate = @now,
		@Description = 'Insert list Empployee for MngShift',
		@TrackingValue = @LogSPData,
		@UserID = @ModifiedBy,
		@EmpID=@EmpID