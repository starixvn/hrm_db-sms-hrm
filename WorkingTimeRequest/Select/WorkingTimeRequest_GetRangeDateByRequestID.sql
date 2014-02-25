USE HRM_SMS
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].WorkingTimeRequest_GetRangeDateByRequestID
	@Requestid bigint,
	@FromDate datetime=NULL output,
	@ToDate datetime=NULL output,
	@TotalDay INT=NULL output,
	@RequestType INT=NULL output
	
AS
/*
Created: Tom.Vo@2013-11-05
Task: Get Range Date From Request ID
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
	
*/
SET NOCOUNT ON;

SELECT TOP 1 @RequestType= RequestType from dbo.WorkingTimeRequest WITH(NOLOCK)
WHERE   RequestID = @RequestID

IF @RequestType IN (6)
	BEGIN
		SELECT TOP 1 @FromDate=FromDate,@ToDate=ToDate,@TotalDay=DATEDIFF(DD,FromDate,ToDate)  FROM [dbo].LeaveRequest r WITH (NOLOCK) WHERE r.RequestId = @requestid
	END
IF @RequestType IN (1,2)
	BEGIN
		SELECT TOP 1 @FromDate=[OnDate],@ToDate=[OnDate],@TotalDay=1  FROM [dbo].[InoutMissRequest] r WITH (NOLOCK) WHERE r.RequestId = @requestid
	END
ELSE IF @RequestType IN (3,4)
	BEGIN
		SELECT TOP 1 @FromDate=FromDate,@ToDate=ToDate,@TotalDay=DATEDIFF(DD,FromDate,ToDate)   FROM [dbo].[InOutRequest] r WITH (NOLOCK) WHERE r.RequestId = @requestid
	END
ELSE IF @RequestType IN (5)
	BEGIN
		SELECT TOP 1 @FromDate=FromDate,@ToDate=ToDate,@TotalDay=DATEDIFF(DD,FromDate,ToDate)   FROM [dbo].ChangeShiftRequest r WITH (NOLOCK) WHERE r.RequestId = @requestid
	END

 