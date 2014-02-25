USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_Update]    Script Date: 2013-11-04 3:37:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[WorkingTimeRequest_Update_CheckInOutRequest]
	@RequestId bigint,
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

	@ModifiedDate datetime=NULL,
	@ModifiedBy int=NULL,
	@RefNo nvarchar(200)='',

	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT	
AS
/*
Created: Tom.Vo@2013-11-04
Task: update a request form
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/

SET NOCOUNT ON

DECLARE
	@FromDate datetime, 
	@ToDate datetime
SELECT @FromDate =@OnDate, @ToDate = @OnDate

IF @CheckTime IS NULL 
	SET @CheckTime=@OnDate

IF EXISTS(SELECT 	TOP 1 1
	FROM dbo.WorkingTimeRequest r WITH(NOLOCK) 	
		WHERE r.RequestId = @RequestId
			AND r.CurrentStatus <> 1)
BEGIN
	SET @ErrCode =100
	SET @ErrMsg = 'Process awaiting approval. You could not edit this request.'
	RETURN;
END

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
			and r.RequestId <> @RequestId
			and datediff(d, l.[OnDate], @FromDate ) = 0
	)
)
BEGIN
	SET @ErrCode =102
	SET @ErrMsg = 'There is another request in the same date'
	RETURN;
END

DECLARE @IsTopManager BIT,@IsDefaultSchedule BIT,@IsLocal  BIT
SELECT @IsTopManager = IsTopManager,@IsDefaultSchedule =IsDefaultSchedule,@IsLocal=IsLocal from dbo.EmployeeSummary WITH(NOLOCK) WHERE EmpId = @EmpId

IF ((@ApproverId IS NULL OR @VerifierId IS NULL) AND @IsTopManager = 0)
BEGIN
	SET @ErrCode =103
	SET @ErrMsg = 'Invalid parameter'
	RETURN;
END

IF @EmpId <> @ModifiedBy
BEGIN
	IF NOT EXISTS (SELECT TOP 1 1
	FROM [dbo].[EmployeeSupervisor] sp WITH(NOLOCK)
	WHERE sp.OwnerId = @EmpId
		AND sp.EmpId = @ModifiedBy
		AND sp.ActionType = 5
		AND sp.RequestType in (1,2)
		)
	BEGIN
		SET @ErrCode = 107
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

/*
DECLARE @SHIFTID INT
SELECT @SHIFTID = SHIFTID FROM dbo.EmployeeCalendar ec WITH(NOLOCK) WHERE WorkDate = CONVERT(NVARCHAR(100),@FromDate,111) AND [EmpId] = @EmpId

IF @SHIFTID IS NULL AND @IsDefaultSchedule = 1
BEGIN
	SELECT @SHIFTID =CASE DATEPART(dw,@FromDate) 
		WHEN 1 THEN ec.SunShift 
		WHEN 2 THEN ec.MonShift 
		WHEN 3 THEN ec.TueShift 
		WHEN 4 THEN ec.WedShift 
		WHEN 5 THEN ec.ThuShift 
		WHEN 6 THEN ec.FriShift 
		WHEN 1 THEN ec.SatShift 
		END
	 FROM dbo.EmployeeDefaultShift ec WITH(NOLOCK) WHERE ec.EmpID = @EmpId
END

DECLARE @BeginTime NVARCHAR(100),@EndTime NVARCHAR(100)
IF @SHIFTID IS NULL 
BEGIN
	SELECT @BeginTime = BeginCheckInTime , @EndTime=BeginCheckOutTime  FROM dbo.Shift WITH(NOLOCK) WHERE ShiftID = @SHIFTID 
END
*/
UPDATE WorkingTimeRequest WITH(ROWLOCK,UPDLOCK)
SET 	
		Remark = @Remark,
		[CurrentStatus]=CASE WHEN @IsTopManager=1 AND @VerifierId IS NOT NULL THEN 1 
				WHEN @IsTopManager=1 AND @ApproverId IS NOT NULL THEN 2 
				WHEN @IsTopManager=1 AND @ApproverId IS NULL THEN 4 
				ELSE 1 END,
		VerifierId = @VerifierId,
		[VerifiedStatus]=CASE WHEN @IsTopManager=1 AND @VerifierId IS NULL THEN 2 ELSE 1 END, -- pending [VerifiedStatus] as default
		ApproverId = @ApproverId,
		[ApprovedStatus]=CASE WHEN @IsTopManager=1 AND @ApproverId IS NULL THEN 2 ELSE 1 END, -- pending [ApprovedStatus] as default
		HRId = @HRId,
		ModifiedBy = @ModifiedBy,
		ModifiedDate = @ModifiedDate
WHERE RequestId = @RequestId

UPDATE [dbo].[InoutMissRequest] WITH(ROWLOCK,UPDLOCK)
SET [EmpId] = @EmpId
	,[OnDate]=CONVERT(nvarchar(100),@FromDate,111)
	,[CheckTime]=@CheckTime
	,[RefNo] = @RefNo
	,[ReworkCount]=[ReworkCount]+1
WHERE RequestId = @RequestId

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

SELECT @ErrCode =0, @ErrMsg = ''

EXEC [WorkingTimeRequest_WriteHistory] @RequestId