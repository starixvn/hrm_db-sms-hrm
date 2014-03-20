--USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_Insert]    Script Date: 2013-11-04 8:12:19 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[WorkingTimeRequest_Insert_KeepInViewRequest]
	@EmpId int, 
	@RequestType smallint,	

	@Remark nvarchar(2000)=NULL,	
	@OnDate datetime=NULL, 
	@IsHalfDay BIT=NULL, 
	@ShiftId numeric(5,1)=NULL, 
	@FromTime datetime=NULL,
	@ToTime datetime=NULL,	
	@ExpExchangeDay decimal(18,2)=NULL,

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
Task: insert a Keep inview request form
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON;

IF (@RequestType IN (7) AND (( @FromTime IS NULL AND @ToTime IS NULL AND @IsHalfDay =1 ) OR @IsHalfDay IS NULL ) ) 
BEGIN
	SET @ErrCode =100
	SET @ErrMsg = 'Keep In request has the invalid parameter'
	RETURN;
END

IF (@RequestType IN (7) AND 
	exists(select top 1 1 from dbo.WorkingTimeRequest r WITH(NOLOCK)
				Inner join dbo.[KeepInViewRequest] l WITH(NOLOCK) ON r.RequestId = l.RequestId
		where r.empid=@empid 
			AND r.RequestType=@RequestType
			AND r.CurrentStatus in  (1,2,3,4,6)
			AND @OnDate BETWEEN l.FromDate AND l.ToDate 
		)
	)
BEGIN
	SET @ErrCode =105
	SET @ErrMsg = 'There is another request in the same range'
	RETURN;
END

IF (NOT EXISTS (SELECT TOP 1 1 FROM dbo.EmployeeCalendar WITH(NOLOCK) WHERE WorkDate = @OnDate AND EmpId = @EmpId AND (IsHoliday = 1 OR IsOffDay = 1)))
BEGIN
	SET @ErrCode =106
	SET @ErrMsg = CONVERT(NVARCHAR(100),@OnDate,106 ) + '  not off date or holiday '
	RETURN
END

IF (NOT EXISTS (SELECT TOP 1 1 FROM dbo.OTDailyRequest OT WITH(NOLOCK) WHERE OT.OvertimeDate = @OnDate AND EmpId = @EmpId))
BEGIN
	SET @ErrCode =107
	SET @ErrMsg = 'You have registered overtime on  ' +CONVERT(NVARCHAR(100),@OnDate,106 ) + '.'
	RETURN
END

DECLARE @IsTopManager BIT
SELECT @IsTopManager = IsTopManager from dbo.EmployeeSummary WITH(NOLOCK) WHERE EmpId = @EmpId

IF ((@ApproverId IS NULL OR @VerifierId IS NULL) AND @IsTopManager = 0)
BEGIN
	SET @ErrCode =101
	SET @ErrMsg = 'Keep In View request has the invalid parameter'
	RETURN;
END

IF @EmpId <> @CreatedBy
BEGIN
	IF NOT EXISTS (SELECT TOP 1 1
	FROM [dbo].[EmployeeSupervisor] sp WITH(NOLOCK)
	WHERE sp.OwnerId = @EmpId
		AND sp.EmpId = @CreatedBy
		AND sp.ActionType = 5
		AND sp.RequestType in (7)
		)
	BEGIN
		SET @ErrCode = 102
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
		AND sp.RequestType in (7)
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
		AND sp.RequestType in (7)
		)
	BEGIN
		SET @ErrCode = 109
		SET @ErrMsg = 'invalid parameter ApproverId.'
		RETURN;
	END
END
EXEC [dbo].WorkingTimeRequest_GetNewRefNoByRequestType 
	@RefNo =@RefNo output,
	@RequestType =7

BEGIN TRY

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

DECLARE @RequestId bigint

SELECT @RequestId = cast(SCOPE_IDENTITY() as bigint)
 
INSERT INTO [dbo].[KeepInViewRequest]
           ([RequestId]
           ,[EmpId]
           ,[FromDate]
		   ,[ToDate]
           ,[IsHalfDay]
           ,[ShiftId]
           ,[FromTime]
           ,[ToTime]
           ,[ExpExchangeDay]
           ,[RefNo])
		VALUES
			(@RequestId,
			@EmpId,
			@OnDate,
			@OnDate,
			@IsHalfDay,
			@ShiftId,
			@FromTime,
			@ToTime,
			@ExpExchangeDay,
			@RefNo
			)
 IF (@ApproverId IS NULL AND @VerifierId IS NULL AND @IsTopManager = 1)
BEGIN
		EXEC [dbo].[WorkingTimeRequest_ApproveRequest_7]
				@RequestID =@RequestID,
				@EmpID =@EmpID,
				@ApprovedBy =@EmpID,
				@ApprovedDate =@CreatedDate ,
				@RoleID =3,
				@ErrCode = @ErrCode  OUTPUT,
				@ErrMsg  = @ErrMsg   OUTPUT
END

EXEC [WorkingTimeRequest_WriteHistory] @RequestId
END TRY
BEGIN CATCH
	
		SELECT @ErrCode = 101, @ErrMsg = N'Create keep in request for an employee failed.'
		DELETE dbo.WorkingTimeRequest WHERE RequestId = @RequestId
		DELETE dbo.[KeepInViewRequest] WHERE RequestId = @RequestId
		Return
END CATCH;

SELECT @RequestId
SELECT @ErrCode = 0,@ErrMsg=''