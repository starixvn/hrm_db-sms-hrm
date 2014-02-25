USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_Update]    Script Date: 2013-11-04 3:37:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[WorkingTimeRequest_Update_LateInEarlyOutRequest]
	@RequestId bigint,
	@EmpId int,
	@RequestType INT=NULL,
	@Remark nvarchar(2000)=NULL,
	@OnDate datetime=NULL,
	@LateInMins int=NULL,
	@EarlyOutMins int=NULL,

	@ModifiedDate datetime=NULL,
	@ModifiedBy int=NULL,
	@RefNo nvarchar(200)='',

	@VerifierId  int=NULL,
    @ApproverId  int=NULL,
    @HRId  int=NULL,

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

IF EXISTS(SELECT 	TOP 1 1
	FROM dbo.WorkingTimeRequest r WITH(NOLOCK) 	
		WHERE r.RequestId = @RequestId
			AND r.CurrentStatus <> 1)
BEGIN
	SET @ErrCode =100
	SET @ErrMsg = 'Process awaiting approval. You could not edit this request.'
	RETURN;
END

IF @RequestType NOT IN (3,4)
BEGIN
	SET @ErrCode =101
	SET @ErrMsg = 'Late in request has the invalid parameter'
	RETURN;
END

IF (@RequestType IN (3) AND (@FromDate IS NULL OR isnull(@LateInMins,0) <= 0 OR isnull(@LateInMins,0) >150))
BEGIN
	SET @ErrCode =102
	SET @ErrMsg = 'Late in request has the invalid parameter'
	RETURN;
END

IF (@RequestType IN (4) AND (@FromDate IS NULL OR isnull(@EarlyOutMins,0) <= 0 OR isnull(@EarlyOutMins,0) >150))
BEGIN
	SET @ErrCode =103
	SET @ErrMsg = 'Late out request has the invalid parameter'
	RETURN;
END

DECLARE	@_FromDate NVARCHAR(100), @_ToDate NVARCHAR(100)

SELECT @_FromDate = CONVERT(VARCHAR(10),@fromDate,111), --+ ' 00:00:00',
		@_ToDate = CONVERT(VARCHAR(10),@toDate,111) --+ ' 00:00:00'

IF (@RequestType IN (3,4) AND 
	exists(select top 1 1 from dbo.WorkingTimeRequest r WITH(NOLOCK)
				Inner join dbo.InOutRequest l WITH(NOLOCK) ON r.RequestId = l.RequestId
		where r.RequestId <> @RequestId
			AND r.empid=@empid 
			AND r.RequestType=@RequestType
			AND r.CurrentStatus in  (1,2,3,4,6)
			AND (CONVERT(VARCHAR(10),l.fromdate,111) BETWEEN @_FromDate AND @_ToDate 
					OR CONVERT(VARCHAR(10),l.todate,111) BETWEEN @_FromDate AND @_ToDate
					OR @_FromDate BETWEEN CONVERT(VARCHAR(10),l.fromdate,111) AND CONVERT(VARCHAR(10),l.todate,111)
					OR @_ToDate BETWEEN CONVERT(VARCHAR(10),l.fromdate,111) AND CONVERT(VARCHAR(10),l.todate,111)
			)
		)
	)
BEGIN
	SET @ErrCode =105
	SET @ErrMsg = 'There is another request in the same range'
	RETURN;
END

DECLARE @IsTopManager BIT,@IsLocal  BIT
SELECT @IsTopManager = IsTopManager,@IsLocal=IsLocal from dbo.EmployeeSummary WITH(NOLOCK) WHERE EmpId = @EmpId

IF ((@ApproverId IS NULL OR @VerifierId IS NULL) AND @IsTopManager = 0)
BEGIN
	SET @ErrCode =106
	SET @ErrMsg = 'Invalid parameter'
	RETURN;
END

-- check the late in, ealry out min <=60 
IF ( (@RequestType = 3 AND @LateInMins > 210)
	or (@RequestType = 4 AND @EarlyOutMins > 210)	
	)
BEGIN
	SET @ErrCode =108
	SET @ErrMsg = 'The maximun late in/early out minutes is 03h30'
	RETURN;
END

IF @EmpId <> @ModifiedBy
BEGIN
	IF NOT EXISTS (SELECT TOP 1 1
	FROM [dbo].[EmployeeSupervisor] sp WITH(NOLOCK)
	WHERE sp.OwnerId = @EmpId
		AND sp.EmpId = @ModifiedBy
		AND sp.ActionType = 5
		AND sp.RequestType in (3,4)
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
		AND sp.RequestType in (3,4)	
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
		AND sp.RequestType in (3,4)
		)
	BEGIN
		SET @ErrCode = 109
		SET @ErrMsg = 'invalid parameter ApproverId.'
		RETURN;
	END
END

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


UPDATE [dbo].[InOutRequest]WITH(ROWLOCK,UPDLOCK)
SET			   
	[EmpId] = @EmpId
	,[LateInMins]=@LateInMins
	,[EarlyOutMins]=@EarlyOutMins
	,[FromDate]=@FromDate
	,[ToDate]=@ToDate
	,[RefNo]=@RefNo
WHERE [RequestId] = @RequestId

IF (@ApproverId IS NULL AND @VerifierId IS NULL AND @IsTopManager = 1)
BEGIN
	IF @RequestType = 3 
		EXEC [dbo].[WorkingTimeRequest_ApproveRequest_3]
				@RequestID =@RequestID,
				@EmpID =@EmpID,
				@ApprovedBy =@EmpID,
				@ApprovedDate =@ModifiedDate ,
				@RoleID =3,
				@ErrCode = @ErrCode  OUTPUT,
				@ErrMsg  = @ErrMsg   OUTPUT
	ELSE IF @RequestType = 4 
			EXEC [dbo].[WorkingTimeRequest_ApproveRequest_4]
				@RequestID =@RequestID,
				@EmpID =@EmpID,
				@ApprovedBy =@EmpID,
				@ApprovedDate =@ModifiedDate ,
				@RoleID =3,
				@ErrCode = @ErrCode  OUTPUT,
				@ErrMsg  = @ErrMsg   OUTPUT
END

SELECT @ErrCode =0, @ErrMsg = ''

EXEC [WorkingTimeRequest_WriteHistory] @RequestId



/*

declare @p12 int
set @p12=NULL
declare @p13 nvarchar(200)
set @p13=NULL
exec WorkingTimeRequest_Update_LateInEarlyOutRequest @RequestId=43,@EmpId=116,@RequestType=4,@Remark=N'123',@OnDate='2013-11-04 00:00:00',@VerifierId=5,@ApproverId=6,@ModifiedDate='2013-11-06 09:41:08.883',@ModifiedBy=116,@LateinMins=NULL,@EarlyOutMins=15,@ErrCode=@p12 output,@ErrMsg=@p13 output
select @p12, @p13


*/