# frozen_string_literal: true

module Cameras
  class SocsController < ApplicationController
    # include InstallationInstructionConcern

    def index
      respond_to do |format|
        format.html {
          @vendor = Vendor.find(params[:vendor])
          if @vendor
            @socs = Soc.left_joins(:vendor).where(vendors: { name: @vendor }).order(:model)
            @page_title = 'Full list of processors'
          end
          render 'cameras/socs/index'
        }
        format.json do
          @data = {
            vendors: Vendor.order(:name).map do |v|
              {
                name: v.name,
                socs: v.socs.order(:model).map do |s|
                  {
                    family: s.family,
                    model: s.model,
                    version: s.version,
                    uboot: s.uboot_filename,
                    kernel: s.kernel,
                    rootfs: s.linux_filename,
                    sdk: s.sdk,
                    load_address: s.load_address,
                    status: s.status,
                  }
                end
              }
            end
          }
          render json: @data #.to_json
        end
      end
    end

    def show
      @camera = Camera.new(
        camera_ip_address: '192.168.1.10',
        server_ip_address: '192.168.1.254',
        flash_type: 'nor8m',
        firmware_version: 'lite',
        network_interface: 'eth',
        sd_card_slot: 'nosd'
      )
      @camera.camera_ip_address = params[:cip] if params[:cip]
      @camera.camera_mac_address = params[:mac].to_s.downcase.gsub('-', ':')
      @camera.server_ip_address = params[:sip] if params[:sip]
      @camera.flash_type = params[:rom] if params[:rom]
      @camera.firmware_version = params[:ver] if params[:ver]
      @camera.network_interface = params[:net] if params[:net]
      @camera.sd_card_slot = params[:sd] if params[:sd]

      @camera.soc = Soc.find_by_urlname(params[:id])
      @vendor = @camera.soc.vendor

      @page_title = "SoC: #{@camera.soc.full_name}"
      render 'cameras/socs/show'
    end

    def update
      @camera = Camera.new(
        camera_ip_address: '192.168.1.10',
        server_ip_address: '192.168.1.254',
        flash_type: 'nor8m',
        firmware_version: 'lite',
        network_interface: 'eth',
        sd_card_slot: 'nosd'
      )
      @camera.camera_ip_address = permitted_params[:camera_ip_address]
      @camera.camera_mac_address = permitted_params[:camera_mac_address].to_s.downcase.gsub('-', ':')
      @camera.server_ip_address = permitted_params[:server_ip_address]
      @camera.flash_type = permitted_params[:flash_type]
      @camera.firmware_version = permitted_params[:firmware_version]
      @camera.network_interface = permitted_params[:network_interface]
      @camera.sd_card_slot = permitted_params[:sd_card_slot]

      # to handle nor32m size still using nor16m command
      @flash_type_command = @camera.flash_type
      @flash_type_command = 'nor16m' if @camera.flash_type.eql?('nor32m')

      @camera.soc = Soc.find(params[:id])
      @vendor = @camera.soc.vendor

      if @vendor.name.eql?("SigmaStar") && @camera.flash_type.eql?("nand")
        render 'cameras/socs/sigmastar_nand_is_weird'
      elsif @camera.soc.model.in?(%w[HI3536CV100 HI3536DV100])
        render 'cameras/socs/hi3536dv100_is_weird'
      else
        if @camera.flash_type.eql?('nor8m') && @camera.firmware_version.eql?('ultimate')
          @camera.firmware_version = 'lite'
          flash.now[:warning] = '8MB Flash ROM can only be flashed with Lite or FPV edition!'
        end

        @camera.backup_filename = "backup-#{@camera.soc.model.downcase}-#{@camera.flash_type}.bin"

        @page_title = "SoC: #{@camera.soc.full_name}"
        render 'cameras/socs/update'
      end
    end

    def download_full_image
      permitted_params = params.permit(:id, :vendor_id, :flash_size, :fw_release, :flash_type)
      flash_size = permitted_params[:flash_size]
      flash_type = permitted_params[:flash_type]
      fw_release = permitted_params[:fw_release]
      @soc = Soc.find(params[:id])
      fw = Firmware.new(size: flash_size, flash_type: flash_type, release: fw_release, soc: @soc)
      fw.generate
      send_file fw.filepath, name: fw.filename, disposition: :attachment
    rescue ActionController::MissingFile => e
      flash.alert = 'This firmware does not exist.'
      redirect_back(fallback_location: '/')
    end

    def featured
      @socs = Soc.left_joins(:vendor).where(featured: true).order(:name, :model)
      @page_title = 'List of recommended SoCs'
      render 'cameras/socs/index'
    end

    def full_list
      @socs = Soc.left_joins(:vendor).order(:name, :model)
      @page_title = 'SoC: full list'
      render 'cameras/socs/index'
    end

    private

    def permitted_params
      params.require(:camera).permit(
        :flash_type, :sd_card_slot, :network_interface, :camera_ip_address,
        :server_ip_address, :firmware_version, :sd_card_slot, :camera_mac_address
      )
    end
  end
end
