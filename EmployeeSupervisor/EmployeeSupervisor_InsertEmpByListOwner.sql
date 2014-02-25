USE [HRM_SMS]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[EmployeeSupervisor_InsertEmpByListOwner]
	@EmpId  INT,
	@Role	TINYINT,
	@EmpIdLeaves VARCHAR(5000) = '',
	@EmpIdChangeShifts VARCHAR(5000) = '',
	@EmpIdLateInEarlyOuts VARCHAR(5000) = '',
	@EmpIdCheckInOuts VARCHAR(5000) = '',
	@EmpIdOvertimes VARCHAR(5000) = '',
	@EmpIdKeepInViews VARCHAR(5000) = '',
	@ModifiedBy INT,
	
	@ErrCode int = 0 OUTPUT,
	@ErrMsg varchar(200) = '' OUTPUT	
AS
/*
Created: @Tom.Vo@2013-10-30
Task: Insert list employee by role (for supervisor list)
DB: HRM_SMS
Original:

Revisions:
Param's Explanation:
*/
SET NOCOUNT ON 

IF OBJECT_ID('tempdb..#SupervisorId_multi') IS NOT NULL
    DROP TABLE #SupervisorId_multi

CREATE TABLE #SupervisorId_multi (OwnerId INT,RequestType	TINYINT,OrderNo SmallINT IDENTITY(1, 1))

IF ISNULL(@EmpIdCheckInOuts,'') <> ''
	BEGIN 
		INSERT INTO #SupervisorId_multi (OwnerId,RequestType)
		SELECT val,RequestType FROM fnc_strSplit (@EmpIdCheckInOuts, ',')  , (SELECT 1 as RequestType) tblRole

		DBCC CHECKIDENT (#SupervisorId_multi, RESEED, 0) WITH NO_INFOMSGS

		INSERT INTO #SupervisorId_multi (OwnerId,RequestType)
		SELECT val,RequestType FROM fnc_strSplit (@EmpIdCheckInOuts, ',')  , (SELECT 2 RequestType) tblRole

		DBCC CHECKIDENT (#SupervisorId_multi, RESEED, 0) WITH NO_INFOMSGS
	END

IF ISNULL(@EmpIdLateInEarlyOuts,'') <> ''
	BEGIN 
		INSERT INTO #SupervisorId_multi (OwnerId,RequestType)
		SELECT val,RequestType FROM fnc_strSplit (@EmpIdLateInEarlyOuts, ',')  , (SELECT 3 as RequestType) tblRole

		DBCC CHECKIDENT (#SupervisorId_multi, RESEED, 0) WITH NO_INFOMSGS

		INSERT INTO #SupervisorId_multi (OwnerId,RequestType)
		SELECT val,RequestType FROM fnc_strSplit (@EmpIdLateInEarlyOuts, ',')  , (SELECT 4 as RequestType) tblRole

		DBCC CHECKIDENT (#SupervisorId_multi, RESEED, 0) WITH NO_INFOMSGS
	END
IF ISNULL(@EmpIdChangeShifts,'') <> ''
	BEGIN
		INSERT INTO #SupervisorId_multi (OwnerId,RequestType)
		SELECT val,RequestType FROM fnc_strSplit (@EmpIdChangeShifts, ',')  , (SELECT 5 as RequestType) tblRole

		DBCC CHECKIDENT (#SupervisorId_multi, RESEED, 0) WITH NO_INFOMSGS
	END
IF ISNULL(@EmpIdLeaves,'') <> ''
	BEGIN
		INSERT INTO #SupervisorId_multi (OwnerId,RequestType)
		SELECT val,RequestType FROM fnc_strSplit (@EmpIdLeaves, ',')  , (SELECT 6 as RequestType) tblRole

		DBCC CHECKIDENT (#SupervisorId_multi, RESEED, 0) WITH NO_INFOMSGS
	END

IF ISNULL(@EmpIdKeepInViews,'') <> ''
	BEGIN
		INSERT INTO #SupervisorId_multi (OwnerId,RequestType)
		SELECT val,RequestType FROM fnc_strSplit (@EmpIdKeepInViews, ',')  , (SELECT 7 as RequestType) tblRole

		DBCC CHECKIDENT (#SupervisorId_multi, RESEED, 0) WITH NO_INFOMSGS
	END
IF ISNULL(@EmpIdOvertimes,'') <> ''
	INSERT INTO #SupervisorId_multi (OwnerId,RequestType)
	SELECT val,RequestType FROM fnc_strSplit (@EmpIdOvertimes, ',')  , (SELECT 8 as RequestType) tblRole


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
FROM #SupervisorId_multi

 IF @@ERROR <> 0 
	SELECT @ErrCode=100,@ErrMsg=N'Insert list employee failed'
ELSE 
	SELECT @ErrCode=0,@ErrMsg=''

DROP TABLE #SupervisorId_multi