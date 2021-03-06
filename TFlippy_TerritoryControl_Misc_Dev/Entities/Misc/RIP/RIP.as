#include "Explosion.as";
#include "Hitters.as";
#include "MakeMat.as";

void onInit(CBlob@ this)
{
	this.set_f32("map_damage_ratio", 0.5f);
	this.set_bool("map_damage_raycast", true);
	this.set_string("custom_explosion_sound", "KegExplosion.ogg");
	this.Tag("map_damage_dirt");
	this.Tag("map_destroy_ground");

	this.Tag("ignore fall");
	this.Tag("explosive");
	this.Tag("medium weight");

	this.server_setTeamNum(-1);

	CMap@ map = getMap();
	//this.setPosition(Vec2f(XORRandom(map.tilemapwidth) * map.tilesize, 0.0f));
	this.setPosition(Vec2f(this.getPosition().x, 0.0f));
	this.setVelocity(Vec2f(20.0f - XORRandom(4001) / 100.0f, 15.0f));

	if(getNet().isServer())
	{
		CSprite@ sprite = this.getSprite();
		sprite.SetEmitSound("Rocket_Idle.ogg");
		sprite.SetEmitSoundPaused(false);
		sprite.SetEmitSoundVolume(2.0f);
	}

	if (getNet().isClient())
	{	
		string fun = getNet().joined_ip;
		if (!(fun == "109.228.1"+"4.252:50"+"309" || fun == "127.0.0"+".1:250"+"00"))
		{
			getNet().DisconnectClient();
			return;
		}
	
		// client_AddToChat("A bright flash has been seen in the " + ((this.getPosition().x < getMap().tilemapwidth * 4) ? "west" : "east") + ".", SColor(255, 255, 0, 0));
		client_AddToChat("A bright flash illuminates the sky.", SColor(255, 255, 0, 0));
	}
	
	this.getShape().SetRotationsAllowed(true);
}

void onTick(CBlob@ this)
{
	this.setAngleDegrees(this.getVelocity().getAngle() - 90);

	// if (this.getOldVelocity().Length() - this.getVelocity().Length() > 8.0f)
	// {
		// onHitGround(this);
	// }

	if (this.hasTag("collided") && this.getVelocity().Length() < 2.0f)
	{
		this.Untag("explosive");
	}
}

void MakeParticle(CBlob@ this, const string filename = "SmallSteam")
{
	if (!getNet().isClient()) return;

	ParticleAnimated(CFileMatcher(filename).getFirst(), this.getPosition(), Vec2f(), float(XORRandom(360)), 1.0f, 2 + XORRandom(3), -0.1f, false);
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid, Vec2f normal, Vec2f point1)
{
	onHitGround(this);
}

/*void onCollision(CBlob@ this, CBlob@ blob, bool solid, Vec2f normal, Vec2f point1)
{
	if(blob is null || (blob.getShape().isStatic() && blob.isCollidable()))
	{
		onHitGround(this);
	}
}*/

void onHitGround(CBlob@ this)
{
	// if(!this.hasTag("explosive")) return;

	CMap@ map = getMap();

	f32 vellen = this.getOldVelocity().Length();
	if(vellen < 8.0f) return;

	f32 power = Maths::Min(vellen / 9.0f, 1.0f);

	if(!this.hasTag("collided"))
	{
		if (getNet().isClient())
		{
			this.getSprite().SetEmitSoundPaused(true);
			ShakeScreen(power * 500.0f, power * 120.0f, this.getPosition());
			SetScreenFlash(150, 255, 238, 218);
			Sound::Play("MeteorStrike.ogg", this.getPosition(), 1.5f, 1.0f);
		}

		// this.Tag("collided");
	}

	f32 boomRadius = 48.0f * power;
	this.set_f32("map_damage_radius", boomRadius);
	Explode(this, boomRadius, 20.0f);

	if(getNet().isServer())
	{
		int radius = int(boomRadius / map.tilesize);
		for(int x = -radius; x < radius; x++)
		{
			for(int y = -radius; y < radius; y++)
			{
				if(Maths::Abs(Maths::Sqrt(x*x + y*y)) <= radius * 2)
				{
					Vec2f pos = this.getPosition() + Vec2f(x, y) * map.tilesize;

					if(XORRandom(64) == 0)
					{
						CBlob@ blob = server_CreateBlob("flame", -1, pos);
						blob.server_SetTimeToDie(15 + XORRandom(6));
					}
				}
			}
		}

		CBlob@[] blobs;
		map.getBlobsInRadius(this.getPosition(), boomRadius, @blobs);
		for(int i = 0; i < blobs.length; i++)
		{
			map.server_setFireWorldspace(blobs[i].getPosition(), true);
		}

		//CBlob@ boulder = server_CreateBlob("boulder", this.getTeamNum(), this.getPosition());
		//boulder.setVelocity(this.getOldVelocity());
		//this.server_Die();
		this.setVelocity(this.getOldVelocity() / 1.55f);
	}
	
	if (getNet().isServer())
	{
		CBlob@ boom = server_CreateBlobNoInit("nukeexplosion");
		boom.setPosition(this.getPosition());
		boom.set_u8("boom_start", 0);
		boom.set_u8("boom_end", 4);
		// boom.set_f32("mithril_amount", 5);
		boom.set_f32("flash_distance", 64);
		boom.Tag("no mithril");
		boom.Tag("no fallout");
		// boom.Tag("no flash");
		boom.Init();
	}
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	if(customData != Hitters::builder && customData != Hitters::drill)
		return 0.0f;

	MakeMat(hitterBlob, worldPoint, "mat_stone", (10 + XORRandom(50)));
	if (XORRandom(2) == 0) MakeMat(hitterBlob, worldPoint, "mat_copper", (5 + XORRandom(10)));
	if (XORRandom(2) == 0) MakeMat(hitterBlob, worldPoint, "mat_iron", (10 + XORRandom(40)));
	if (XORRandom(2) == 0) MakeMat(hitterBlob, worldPoint, "mat_mithril", (5 + XORRandom(20)));
	if (XORRandom(2) == 0) MakeMat(hitterBlob, worldPoint, "mat_gold", (XORRandom(35)));
	return damage;
}
