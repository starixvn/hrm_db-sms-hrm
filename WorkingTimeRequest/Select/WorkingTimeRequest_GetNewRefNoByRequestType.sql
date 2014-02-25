USE HRM_SMS
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].WorkingTimeRequest_GetNewRefNoByRequestType  
	@RefNo NVARCHAR(100)=NULL output,
	@RequestType INT=NULL
	
AS
/*
Created: Tom.Vo@2013-11-05
Task: Get New RefNo From Request Type
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
	
*/
SET NOCOUNT ON;

IF @RequestType IN (1,2)
		SELECT @RefNo=Max(RefNo)  
			FROM [dbo].LeaveRequest r WITH (NOLOCK) 
				INNER JOIN [dbo].WorkingTimeRequest wr WITH (NOLOCK) 
					ON r.RequestId = wr.RequestId
				WHERE wr.RequestType in (1,2)
ELSE IF @RequestType IN (3,4)
		SELECT  @RefNo=Max(RefNo) FROM [dbo].[InOutRequest] r WITH (NOLOCK)
				INNER JOIN [dbo].WorkingTimeRequest wr WITH (NOLOCK) 
						ON r.RequestId = wr.RequestId
					WHERE wr.RequestType in (3,4)
ELSE IF @RequestType IN (5)
		SELECT @RefNo = ''
ELSE IF @RequestType IN (6)
		SELECT @RefNo=Max(RefNo)  
		FROM [dbo].LeaveRequest r WITH (NOLOCK) 
			INNER JOIN [dbo].WorkingTimeRequest wr WITH (NOLOCK) 
				ON r.RequestId = wr.RequestId
			WHERE wr.RequestType in (6)
 ELSE IF @RequestType IN (7)
		SELECT @RefNo=Max(RefNo)  
		FROM [dbo].KeepInViewRequest r WITH (NOLOCK) 
			INNER JOIN [dbo].WorkingTimeRequest wr WITH (NOLOCK) 
				ON r.RequestId = wr.RequestId
			WHERE wr.RequestType in (7)
 DECLARE @Num INT
 --Ref-000001
 IF ISNULL(@RefNo,'')=''
	SET @RefNo= CASE WHEN @RequestType IN (6) THEN 'Ref-000001' 
					WHEN @RequestType IN (7) THEN 'KIV-000001' 
					ELSE 'Ref-000001' END				
ELSE 
	BEGIN
		SET @Num = CONVERT(INT,RIGHT(@RefNo,LEN(@RefNo)-4))+1
		SET @RefNo=CASE WHEN @RequestType IN (6) THEN 'Ref-' 
					WHEN @RequestType IN (7) THEN 'KIV-' 
					ELSE 'Ref-' END  +REPLICATE('0', 6-LEN(@Num))+ CONVERT(NVARCHAR(100),@Num)
	END