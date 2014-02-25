USE [HRM_SMS]
GO
/****** Object:  StoredProcedure [dbo].[LookupData_JobTitle_SELECT]    Script Date: 2013-10-29 4:05:59 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[LookupData_Marriage_SELECT]
	@Marriage VARCHAR(100)	= ''
AS
/*
Created: Tom.Vo@2013-10-29
Task: Get Marriage  
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @lookupId INT
	SELECT @lookupId = Id FROM dbo.[Lookup] WITH (NOLOCK) WHERE Code ='Marriage'

	IF @Marriage IS NULL
		SET @Marriage = ''
	
	IF @Marriage <> ''
		SELECT l.Id,
				l.LookupId,
				l.Code,
				l.Name,
				l.Value
		FROM dbo.LookupData AS l WITH(NOLOCK) 
		WHERE LookupId = @lookupId
			AND l.Name LIKE '%'+ @Marriage +'%'			
		GROUP BY l.LookupId,l.id,l.Code,l.Name,l.Value
		ORDER BY l.Value
	ELSE
		SELECT l.Id,
				l.LookupId,
				l.Code,
				l.Name,
				l.Value 
		FROM dbo.LookupData AS l WITH(NOLOCK) 
		WHERE LookupId = @lookupId
		GROUP BY l.LookupId,l.id,l.Code,l.Name,l.Value
		ORDER BY l.Value 
END