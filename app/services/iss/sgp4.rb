# frozen_string_literal: true

module Iss
  # Pure-Ruby near-Earth SGP4 propagator (Vallado / Spacetrack Report #3).
  # Outputs position and velocity in the TEME frame.
  class Sgp4
    DEG2RAD = Math::PI / 180.0
    TWOPI = 2.0 * Math::PI
    X2O3 = 2.0 / 3.0
    TEMP4 = 1.5e-12

    # WGS-72 constants used by NORAD TLEs.
    MU = 398_600.8
    RADIUS_EARTH_KM = 6378.135
    XKE = 60.0 / Math.sqrt(RADIUS_EARTH_KM**3 / MU)
    TUMIN = 1.0 / XKE
    J2 = 0.001082616
    J3 = -0.00000253881
    J4 = -0.00000165597
    J3OJ2 = J3 / J2

    class PropagationError < StandardError; end

  private_constant :DEG2RAD, :TWOPI, :X2O3, :TEMP4,
                   :MU, :RADIUS_EARTH_KM, :XKE, :TUMIN,
                   :J2, :J3, :J4, :J3OJ2

    def initialize(tle)
      @tle = tle
      @operationmode = "i"
      initialize_state!
    end

    # @param time [Time] UTC instant
    # @return [Hash] position_m and velocity_mps arrays in TEME
    def propagate(time)
      tsince = (time.to_r - @tle.epoch.to_r) / 60r
      position_km, velocity_km_s = propagate_since_epoch(tsince.to_f)

      {
        position_m: position_km.map { |km| km * 1000.0 },
        velocity_mps: velocity_km_s.map { |km_s| km_s * 1000.0 }
      }
    end

    private

    def initialize_state!
      reset_state!

      @bstar = @tle.bstar
      @ndot = @tle.ndot_sgp4
      @nddot = @tle.nddot_sgp4
      @ecco = @tle.eccentricity
      @argpo = @tle.argp_rad
      @inclo = @tle.inclination_rad
      @mo = @tle.mean_anomaly_rad
      @no_kozai = @tle.mean_motion_rad_per_min
      @nodeo = @tle.raan_rad
      @epoch = @tle.epoch_days_since_1950

      no_unkozai, _method, ainv, ao, con41, con42, cosio, cosio2, eccsq,
        omeosq, posq, rp, rteosq, sinio, gsto = initl(@ecco, @epoch, @inclo, @no_kozai)

      @no_unkozai = no_unkozai
      @gsto = gsto
      @con41 = con41
      @con42 = con42
      @cosio = cosio
      @cosio2 = cosio2
      @sinio = sinio

      period_min = TWOPI / @no_unkozai
      if period_min >= 225.0
        raise PropagationError, "Deep-space orbits (period >= 225 min) are not supported"
      end

      @method = "n"
      @isimp = 0
      if rp < (220.0 / RADIUS_EARTH_KM) + 1.0
        @isimp = 1
      end

      ss = (78.0 / RADIUS_EARTH_KM) + 1.0
      qzms2t = ((120.0 - 78.0) / RADIUS_EARTH_KM)**4
      sfour = ss
      qzms24 = qzms2t
      perige = (rp - 1.0) * RADIUS_EARTH_KM

      if perige < 156.0
        sfour = perige - 78.0
        sfour = 20.0 if perige < 98.0
        qzms24 = ((120.0 - sfour) / RADIUS_EARTH_KM)**4
        sfour = (sfour / RADIUS_EARTH_KM) + 1.0
      end

      pinvsq = 1.0 / posq
      tsi = 1.0 / (ao - sfour)
      @eta = ao * @ecco * tsi
      etasq = @eta * @eta
      eeta = @ecco * @eta
      psisq = (1.0 - etasq).abs
      coef = qzms24 * tsi**4
      coef1 = coef / psisq**3.5
      cc2 = coef1 * @no_unkozai * (
        ao * (1.0 + 1.5 * etasq + eeta * (4.0 + etasq)) +
        0.375 * J2 * tsi / psisq * @con41 * (8.0 + 3.0 * etasq * (8.0 + etasq))
      )
      @cc1 = @bstar * cc2
      cc3 = 0.0
      if @ecco > 1.0e-4
        cc3 = -2.0 * coef * tsi * J3OJ2 * @no_unkozai * sinio / @ecco
      end
      @x1mth2 = 1.0 - cosio2
      @cc4 = 2.0 * @no_unkozai * coef1 * ao * omeosq * (
        @eta * (2.0 + 0.5 * etasq) + @ecco * (0.5 + 2.0 * etasq) -
        J2 * tsi / (ao * psisq) * (
          -3.0 * @con41 * (1.0 - 2.0 * eeta + etasq * (1.5 - 0.5 * eeta)) +
          0.75 * @x1mth2 * (2.0 * etasq - eeta * (1.0 + etasq)) * Math.cos(2.0 * @argpo)
        )
      )
      @cc5 = 2.0 * coef1 * ao * omeosq * (1.0 + 2.75 * (etasq + eeta) + eeta * etasq)
      cosio4 = cosio2 * cosio2
      temp1 = 1.5 * J2 * pinvsq * @no_unkozai
      temp2 = 0.5 * temp1 * J2 * pinvsq
      temp3 = -0.46875 * J4 * pinvsq * pinvsq * @no_unkozai
      @mdot = @no_unkozai + 0.5 * temp1 * rteosq * @con41 + 0.0625 * temp2 * rteosq * (13.0 - 78.0 * cosio2 + 137.0 * cosio4)
      @argpdot = (
        -0.5 * temp1 * con42 + 0.0625 * temp2 * (7.0 - 114.0 * cosio2 + 395.0 * cosio4) +
        temp3 * (3.0 - 36.0 * cosio2 + 49.0 * cosio4)
      )
      xhdot1 = -temp1 * cosio
      @nodedot = xhdot1 + (0.5 * temp2 * (4.0 - 19.0 * cosio2) + 2.0 * temp3 * (3.0 - 7.0 * cosio2)) * cosio
      @omgcof = @bstar * cc3 * Math.cos(@argpo)
      @xmcof = 0.0
      @xmcof = -X2O3 * coef * @bstar / eeta if @ecco > 1.0e-4
      @nodecf = 3.5 * omeosq * xhdot1 * @cc1
      @t2cof = 1.5 * @cc1
      @xlcof = if (@cosio + 1.0).abs > 1.5e-12
        -0.25 * J3OJ2 * sinio * (3.0 + 5.0 * @cosio) / (1.0 + @cosio)
      else
        -0.25 * J3OJ2 * sinio * (3.0 + 5.0 * @cosio) / TEMP4
      end
      @aycof = -0.5 * J3OJ2 * sinio
      delmotemp = 1.0 + @eta * Math.cos(@mo)
      @delmo = delmotemp * delmotemp * delmotemp
      @sinmao = Math.sin(@mo)
      @x7thm1 = 7.0 * cosio2 - 1.0

      if @isimp != 1
        cc1sq = @cc1 * @cc1
        @d2 = 4.0 * ao * tsi * cc1sq
        temp = @d2 * tsi * @cc1 / 3.0
        @d3 = (17.0 * ao + sfour) * temp
        @d4 = 0.5 * temp * ao * tsi * (221.0 * ao + 31.0 * sfour) * @cc1
        @t3cof = @d2 + 2.0 * cc1sq
        @t4cof = 0.25 * (3.0 * @d3 + @cc1 * (12.0 * @d2 + 10.0 * cc1sq))
        @t5cof = 0.2 * (
          3.0 * @d4 + 12.0 * @cc1 * @d3 + 6.0 * @d2 * @d2 +
          15.0 * cc1sq * (2.0 * @d2 + cc1sq)
        )
      end

      propagate_since_epoch(0.0)
    end

    def reset_state!
      @isimp = 0
      @method = "n"
      @aycof = @con41 = @cc1 = @cc4 = @cc5 = 0.0
      @d2 = @d3 = @d4 = @delmo = @eta = 0.0
      @argpdot = @omgcof = @sinmao = 0.0
      @t = 0.0
      @t2cof = @t3cof = @t4cof = @t5cof = 0.0
      @x1mth2 = @x7thm1 = 0.0
      @mdot = @nodedot = 0.0
      @xlcof = @xmcof = @nodecf = 0.0
      @error = 0
    end

    def initl(ecco, epoch, inclo, no)
      eccsq = ecco * ecco
      omeosq = 1.0 - eccsq
      rteosq = Math.sqrt(omeosq)
      cosio = Math.cos(inclo)
      cosio2 = cosio * cosio

      ak = (XKE / no)**X2O3
      d1 = 0.75 * J2 * (3.0 * cosio2 - 1.0) / (rteosq * omeosq)
      del = d1 / (ak * ak)
      adel = ak * (1.0 - del * del - del * (1.0 / 3.0 + 134.0 * del * del / 81.0))
      del = d1 / (adel * adel)
      no = no / (1.0 + del)

      ao = (XKE / no)**X2O3
      sinio = Math.sin(inclo)
      po = ao * omeosq
      con42 = 1.0 - 5.0 * cosio2
      con41 = -con42 - cosio2 - cosio2
      ainv = 1.0 / ao
      posq = po * po
      rp = ao * (1.0 - ecco)
      method = "n"
      gsto = gstime(epoch + 2_433_281.5)

      [ no, method, ainv, ao, con41, con42, cosio, cosio2, eccsq, omeosq, posq, rp, rteosq, sinio, gsto ]
    end

    def gstime(jdut1)
      tut1 = (jdut1 - 2_451_545.0) / 36_525.0
      temp = (
        -6.2e-6 * tut1 * tut1 * tut1 + 0.093104 * tut1 * tut1 +
        ((876_600.0 * 3600) + 8_640_184.812866) * tut1 + 67_310.54841
      )
      temp = (temp * DEG2RAD / 240.0) % TWOPI
      temp += TWOPI if temp < 0.0
      temp
    end

    def propagate_since_epoch(tsince)
      @t = tsince
      @error = 0
      vkmpersec = RADIUS_EARTH_KM * XKE / 60.0

      xmdf = @mo + @mdot * @t
      argpdf = @argpo + @argpdot * @t
      nodedf = @nodeo + @nodedot * @t
      argpm = argpdf
      mm = xmdf
      t2 = @t * @t
      nodem = nodedf + @nodecf * t2
      tempa = 1.0 - @cc1 * @t
      tempe = @bstar * @cc4 * @t
      templ = @t2cof * t2

      if @isimp != 1
        delomg = @omgcof * @t
        delmtemp = 1.0 + @eta * Math.cos(xmdf)
        delm = @xmcof * (delmtemp * delmtemp * delmtemp - @delmo)
        temp = delomg + delm
        mm = xmdf + temp
        argpm = argpdf - temp
        t3 = t2 * @t
        t4 = t3 * @t
        tempa -= @d2 * t2 + @d3 * t3 + @d4 * t4
        tempe += @bstar * @cc5 * (Math.sin(mm) - @sinmao)
        templ += @t3cof * t3 + t4 * (@t4cof + @t * @t5cof)
      end

      nm = @no_unkozai
      em = @ecco
      inclm = @inclo

      raise_error!(2, "mean motion #{nm} is less than zero") if nm <= 0.0

      am = ((XKE / nm)**X2O3) * tempa * tempa
      nm = XKE / am**1.5
      em -= tempe

      raise_error!(1, "mean eccentricity #{em} not within range 0.0 <= e < 1.0") if em >= 1.0 || em < -0.001

      em = 1.0e-6 if em < 1.0e-6
      mm += @no_unkozai * templ
      xlm = mm + argpm + nodem
      emsq = em * em

      nodem = positive_mod(nodem, TWOPI)
      argpm = positive_mod(argpm, TWOPI)
      xlm = positive_mod(xlm, TWOPI)
      mm = positive_mod(xlm - argpm - nodem, TWOPI)

      sinim = Math.sin(inclm)
      Math.cos(inclm)

      ep = em
      xincp = inclm
      argpp = argpm
      nodep = nodem
      mp = mm
      Math.sin(xincp)
      Math.cos(xincp)

      raise_error!(3, "perturbed eccentricity #{ep} not within range 0.0 <= e <= 1.0") if ep < 0.0 || ep > 1.0

      axnl = ep * Math.cos(argpp)
      temp = 1.0 / (am * (1.0 - ep * ep))
      aynl = ep * Math.sin(argpp) + temp * @aycof
      xl = mp + argpp + nodep + temp * @xlcof * axnl

      u = positive_mod(xl - nodep, TWOPI)
      eo1 = u
      tem5 = 9999.9
      ktr = 1
      while tem5.abs >= 1.0e-12 && ktr <= 10
        sineo1 = Math.sin(eo1)
        coseo1 = Math.cos(eo1)
        tem5 = 1.0 - coseo1 * axnl - sineo1 * aynl
        tem5 = (u - aynl * coseo1 + axnl * sineo1 - eo1) / tem5
        tem5 = tem5.positive? ? 0.95 : -0.95 if tem5.abs >= 0.95
        eo1 += tem5
        ktr += 1
      end

      ecose = axnl * coseo1 + aynl * sineo1
      esine = axnl * sineo1 - aynl * coseo1
      el2 = axnl * axnl + aynl * aynl
      pl = am * (1.0 - el2)
      raise_error!(4, "semilatus rectum #{pl} is less than zero") if pl < 0.0

      rl = am * (1.0 - ecose)
      rdotl = Math.sqrt(am) * esine / rl
      rvdotl = Math.sqrt(pl) / rl
      betal = Math.sqrt(1.0 - el2)
      temp = esine / (1.0 + betal)
      sinu = am / rl * (sineo1 - aynl - axnl * temp)
      cosu = am / rl * (coseo1 - axnl + aynl * temp)
      su = Math.atan2(sinu, cosu)
      sin2u = (cosu + cosu) * sinu
      cos2u = 1.0 - 2.0 * sinu * sinu
      temp = 1.0 / pl
      temp1 = 0.5 * J2 * temp
      temp2 = temp1 * temp

      cosip = Math.cos(xincp)
      sinip = Math.sin(xincp)

      mrt = rl * (1.0 - 1.5 * temp2 * betal * @con41) + 0.5 * temp1 * @x1mth2 * cos2u
      su -= 0.25 * temp2 * @x7thm1 * sin2u
      xnode = nodep + 1.5 * temp2 * cosip * sin2u
      xinc = xincp + 1.5 * temp2 * cosip * sinip * cos2u
      mvt = rdotl - nm * temp1 * @x1mth2 * sin2u / XKE
      rvdot = rvdotl + nm * temp1 * (@x1mth2 * cos2u + 1.5 * @con41) / XKE

      sinsu = Math.sin(su)
      cossu = Math.cos(su)
      snod = Math.sin(xnode)
      cnod = Math.cos(xnode)
      sini = Math.sin(xinc)
      cosi = Math.cos(xinc)
      xmx = -snod * cosi
      xmy = cnod * cosi
      ux = xmx * sinsu + cnod * cossu
      uy = xmy * sinsu + snod * cossu
      uz = sini * sinsu
      vx = xmx * cossu - cnod * sinsu
      vy = xmy * cossu - snod * sinsu
      vz = sini * cossu

      mr = mrt * RADIUS_EARTH_KM
      r = [ mr * ux, mr * uy, mr * uz ]
      v = [
        (mvt * ux + rvdot * vx) * vkmpersec,
        (mvt * uy + rvdot * vy) * vkmpersec,
        (mvt * uz + rvdot * vz) * vkmpersec
      ]

      raise_error!(6, "mrt #{mrt} is less than 1.0 indicating the satellite has decayed") if mrt < 1.0

      [ r, v ]
    end

    def positive_mod(value, modulus)
      value >= 0.0 ? value % modulus : -((-value) % modulus)
    end

    def raise_error!(code, message)
      @error = code
      raise PropagationError, message
    end
  end
end
