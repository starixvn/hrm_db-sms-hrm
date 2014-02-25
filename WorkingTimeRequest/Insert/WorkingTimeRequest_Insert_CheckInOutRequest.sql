USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_Insert]    Script Date: 2013-11-04 8:12:19 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[WorkingTimeRequest_Insert_CheckInOutRequest]
	@EmpId int, 
	@RequestType smallint,	

	@Remark nvarchar(2000)=NULL,	
	@OnDate datetime=NULL, 
	@CheckTime datetime=NULL, 

	@CreatedDate datetime=NULL,
	@CreatedBy int=NULL,

	@VerifierId  int=NULL,
    @ApproverId  int=NULL,
    @HRId  int=NULL,

	@RefNo nvarchar(200)='',

	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT	
AS
/*
Created: Tom.Vo@2013-11-04
Task: insert Check In Out  request form
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON;
DECLARE
	@FromDate datetime, 
	@ToDate datetime
SELECT @FromDate =@OnDate, @ToDate = @OnDate

IF @CheckTime IS NULL 
	SET @CheckTime=@OnDate

IF @RequestType NOT IN (1,2)
BEGIN
	SET @ErrCode =100
	SET @ErrMsg = 'Late in request has the invalid parameter'
	RETURN;
END


IF (@RequestType IN (1,2) AND @FromDate IS NULL)
BEGIN
	SET @ErrCode =101
	SET @ErrMsg = 'Missing check in/out request has the invalid parameter'
	RETURN;
END

-- check if there is another request in the same date
IF (@RequestType IN (1,2) AND 
	exists(select top 1 1 from dbo.WorkingTimeRequest r WITH(NOLOCK)
					Inner join dbo.[InoutMissRequest] l WITH(NOLOCK) ON r.RequestId = l.RequestId
		where r.empid=@empid 
			and RequestType=@RequestType
			and CurrentStatus in  (1,2,3,4,6)
			and datediff(d, l.[OnDate], @FromDate ) = 0
	)
)
BEGIN
	SET @ErrCode =106
	SET @ErrMsg = 'There is another request in the same date'
	RETURN;
END

DECLARE @IsTopManager BIT,@IsLocal  BIT
SELECT @IsTopManager = IsTopManager,@IsLocal=IsLocal from dbo.EmployeeSummary WITH(NOLOCK) WHERE EmpId = @EmpId

IF ((@ApproverId IS NULL OR @VerifierId IS NULL) AND @IsTopManager = 0)
BEGIN
	SET @ErrCode =107
	SET @ErrMsg = 'Invalid parameter'
	RETURN;
END

IF @EmpId <> @CreatedBy
BEGIN
	IF NOT EXISTS (SELECT TOP 1 1
	FROM [dbo].[EmployeeSupervisor] sp WITH(NOLOCK)
	WHERE sp.OwnerId = @EmpId
		AND sp.EmpId = @CreatedBy
		AND sp.ActionType = 5
		AND sp.RequestType in (1,2)
		)
	BEGIN
		SET @ErrCode = 108
		SET @ErrMsg = 'You could not permision on this request.'
		RETURN;
	END
END

IF @IsTopManager = 0
BEGIN
	IF NOT EXISTS (SELECT TOP 1 1
	FROM [dbo].[EmployeeSupervisor] sp WITH(NOLOCK)
	WHERE sp.OwnerId = @VerifierId
		AND sp.EmpId = @EmpId
		AND sp.ActionType = 2
		AND sp.RequestType in (1,2)
		)
	BEGIN
		SET @ErrCode = 108
		SET @ErrMsg = 'invalid parameter verifierid.'
		RETURN;
	END
	IF NOT EXISTS (SELECT TOP 1 1
	FROM [dbo].[EmployeeSupervisor] sp WITH(NOLOCK)
	WHERE sp.OwnerId = @ApproverId
		AND sp.EmpId = @EmpId
		AND sp.ActionType = 3
		AND sp.RequestType in (1,2)
		)
	BEGIN
		SET @ErrCode = 109
		SET @ErrMsg = 'invalid parameter ApproverId.'
		RETURN;
	END
END

INSERT INTO dbo.WorkingTimeRequest
(	   [EmpId]
      ,[RequestType]
      ,[Remark]
      ,[CurrentStatus]
      ,[VerifierId]
      ,[ApproverId]
      ,[HRId]
      ,[VerifiedStatus]
      ,[ApprovedStatus]
      ,[HRStatus]
      ,[CreatedDate]
	  ,[CreatedBy]
)
VALUES
(
	@EmpId, 
	@RequestType,	
	@Remark,
	CASE WHEN @IsTopManager=1 AND @VerifierId IS NOT NULL THEN 1 
		WHEN @IsTopManager=1 AND @ApproverId IS NOT NULL THEN 2 
		WHEN @IsTopManager=1 AND @ApproverId IS NULL THEN 4 
		ELSE 1 END, -- pending [CurrentStatus] as default
	@VerifierId,
	@ApproverId,
	@HRId,
	CASE WHEN @IsTopManager=1 AND @VerifierId IS NULL THEN 2 ELSE 1 END, -- pending [VerifiedStatus] as default
	CASE WHEN @IsTopManager=1 AND @ApproverId IS NULL THEN 2 ELSE 1 END, -- pending [ApprovedStatus] as default
	1, -- pending [HRStatus] as default
	@CreatedDate, 
	@CreatedBy
)


--	@IsOvertimeHours
DECLARE @RequestId bigint

SELECT @RequestId = cast(SCOPE_IDENTITY() as bigint)

IF (@RequestType IN (1,2) )
	BEGIN
		INSERT INTO [dbo].[InoutMissRequest]
				   ([RequestId]
				   ,[EmpId]
				   ,[OnDate]
				   ,[CheckTime]
				   ,[RefNo])
			 VALUES
					(@RequestId,
					@EmpId,
					CONVERT(NVARCHAR(100),@FromDate,111),
					@CheckTime,
					@RefNo
					)

	END

IF (@ApproverId IS NULL AND @VerifierId IS NULL AND @IsTopManager = 1)
BEGIN
	IF @RequestType = 1 
		EXEC [dbo].[WorkingTimeRequest_ApproveRequest_1]
				@RequestID =@RequestID,
				@EmpID =@EmpID,
				@ApprovedBy =@EmpID,
				@ApprovedDate =@CreatedDate ,
				@RoleID =3,
				@ErrCode = @ErrCode  OUTPUT,
				@ErrMsg  = @ErrMsg   OUTPUT
	ELSE IF @RequestType = 2 
			EXEC [dbo].[WorkingTimeRequest_ApproveRequest_2]
				@RequestID =@RequestID,
				@EmpID =@EmpID,
				@ApprovedBy =@EmpID,
				@ApprovedDate =@CreatedDate ,
				@RoleID =3,
				@ErrCode = @ErrCode  OUTPUT,
				@ErrMsg  = @ErrMsg   OUTPUT
END

EXEC [WorkingTimeRequest_WriteHistory] @RequestId 

SELECT @RequestId
SET @ErrCode = 0