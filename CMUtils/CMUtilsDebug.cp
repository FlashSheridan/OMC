//**************************************************************************************
// Filename:	CMUtilsDebug.cp
//				Part of Contextual Menu Workshop by Abracode Inc.
//				http://free.abracode.com/cmworkshop/
//
// Copyright © 2002-2004 Abracode, Inc.  All rights reserved.
//
// Description:	static utilities for Contextual Menu Plugins
//
//
//**************************************************************************************

#include "CMUtils.h"
#include "DebugSettings.h"

// ---------------------------------------------------------------------------------
//		• BufToHex
// ---------------------------------------------------------------------------------

void
CMUtils::BufToHex( const unsigned char* src, char *dest, ByteCount srcLen, ByteCount &destLen, UInt8 clumpSize /*=0*/)
{
	static unsigned char hex[16] =
	{
		'0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'
	};

	UInt8			tempClumpSize = clumpSize;

	destLen=0;
	while(srcLen--)
	{
		*dest++ = *( hex + ((*src&0xF0)>>4) );
		*dest++ = *( hex + ( *src&0x0F ) );
		destLen+=2;
		
		if( clumpSize != 0 )
		{
			if( --tempClumpSize == 0 )
			{
				*dest++ = ' ';
				tempClumpSize = clumpSize;
				destLen++;
			}
		}
		
		src++;
	}
	
	*dest = 0;
}
